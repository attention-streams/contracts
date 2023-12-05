// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/ITopic.sol";
import "./interfaces/IArena.sol";
import "./interfaces/IChoice.sol";

struct Cycle {
    uint256 number;
    uint256 shares;
    uint256 fees;
    bool hasContributions;
}

struct Position {
    uint256 cycleIndex;
    uint256 tokens;
    bool exists;
}

contract Choice is IChoice {
    using SafeERC20 for IERC20;

    address public immutable topicAddress;
    uint256 public immutable startTime;
    uint256 public immutable cycleDuration;
    uint256 public immutable contributorFee;
    uint256 public immutable topicFee;
    uint256 public immutable arenaFee;
    uint256 public immutable arenaAndTopicFee; // arenaFee + topicFee
    uint256 public immutable accrualRate;
    address public immutable token; // contribution token
    string public metadataURI; // string cannot be marked as immutable, however it is never modified after construction

    // The total number of tokens in this Choice. This should equal balanceOf(address(this)), but we don't want to have
    // to repeatedly call the token contract, so we keep track internally.
    uint256 public tokens;

    uint256 public unsettledFees; // arena and topic fees to be settled

    Cycle[] public cycles;

    // Addresses can contribute multiple times to the same choice, so the value is an array of Contributions.
    // The index of a Contribution in this array is used in checkPosition(), withdraw(), split(), and
    // transferPositions() and is returned by contribute().
    mapping(address => Position[]) public positionsByAddress;

    event Withdrew(address indexed addr, uint256 positionIndex, uint256 tokens, uint256 shares);
    event Contributed(address indexed addr, uint256 positionIndex, uint256 tokens);
    event PositionTransferred(
        address indexed sender,
        address indexed recipient,
        uint256 senderPositionIndex,
        uint256 recipientPositionIndex
    );
    event Split(
        address indexed addr,
        uint256 originalPositionIndex,
        uint256 numNewPositions,
        uint256 firstNewPositionIndex,
        uint256 amountPerNewPosition
    );
    event SettledFees(uint256 arenaFeeAmount, uint256 topicFeeAmount);

    error PositionDoesNotExist();
    error NotOnlyPosition();
    error SplitMoreThanAvailable();

    modifier singlePosition(address addr) {
        uint256 numPositions = positionsByAddress[addr].length;

        if (numPositions == 0) {
            revert PositionDoesNotExist();
        }

        if (numPositions > 1) {
            revert NotOnlyPosition();
        }

        _;
    }

    modifier positionExists(address addr, uint256 positionIndex) {
        Position[] storage positions = positionsByAddress[addr];

        unchecked {
            if (positionIndex + 1 > positions.length) revert PositionDoesNotExist();
        }

        Position storage position = positions[positionIndex];

        if (!position.exists) revert PositionDoesNotExist();

        _;
    }

    /// @param _metadataURI: The URI for the metadata of this choice. pass empty string if no metadata.
    constructor(string memory _metadataURI) {
        address topic = msg.sender;
        IArena _arena = IArena(ITopic(topic).arena());
        startTime = ITopic(topic).startTime();
        cycleDuration = ITopic(topic).cycleDuration();
        topicAddress = topic;
        contributorFee = ITopic(topic).contributorFee();
        topicFee = ITopic(topic).topicFee();
        accrualRate = ITopic(topic).accrualRate();
        metadataURI = _metadataURI;
        arenaFee = _arena.arenaFee();
        token = _arena.token();
        arenaAndTopicFee = arenaFee + topicFee;
    }

    function currentCycleNumber() public view returns (uint256) {
        return (block.timestamp - startTime) / cycleDuration;
    }

    /// @return The number of shares all contributors hold in this choice.
    /// The total shares can be compared between two choices to see which has more support.
    function totalShares() external view returns (uint256) {
        return totalSharesAtCycle(currentCycleNumber());
    }

    /// @param cycleNumber The cycle number to compute shares for.
    function totalSharesAtCycle(uint256 cycleNumber) public view returns (uint256) {
        Cycle storage lastStoredCycle = cycles[cycles.length - 1];
        uint256 _currentCycleNumber = currentCycleNumber();

        require(cycleNumber >= _currentCycleNumber, "INVALID_CYCLE");

        return lastStoredCycle.shares + pendingShares(cycleNumber, tokens);
    }

    /// Check the number of tokens and shares for an address with only one position.
    function checkPosition(
        address addr
    ) external view singlePosition(addr) returns (uint256 positionTokens, uint256 shares) {
        return checkPosition(addr, 0);
    }

    function positionsLength(address addr) external view returns (uint256) {
        return positionsByAddress[addr].length;
    }

    function contribute(uint256 amount) external returns (uint256 positionIndex) {
        return contributeFor(amount, msg.sender);
    }

    /// @notice Contribute tokens to this choice, the tokens are always transferred from msg.sender
    /// @param receiver The address that will receive the tokens and shares.
    /// @param amount The amount of tokens to contribute
    /// @return positionIndex will be reused as input to withdraw(), checkPosition(), and other functions
    function contributeFor(uint256 amount, address receiver) public returns (uint256 positionIndex) {
        address addr = receiver;
        uint256 originalAmount = amount;

        // take arena and topic fees
        uint256 _arenaAndTopicFees = (originalAmount * (arenaAndTopicFee)) / 10000;
        amount -= _arenaAndTopicFees;
        unsettledFees += _arenaAndTopicFees;

        uint256 _contributorFee = (originalAmount * contributorFee) / 10000;

        tokens += amount;

        updateCyclesAddingAmount(amount, _contributorFee);

        uint256 lastStoredCycleIndex;

        unchecked {
            // updateCyclesAddingAmount() will always add a cycle if none exists
            lastStoredCycleIndex = cycles.length - 1;

            if (lastStoredCycleIndex > 0) {
                // Contributor fees are only charged in cycles after the one in which the first contribution was made.
                amount -= _contributorFee;
            }
        }

        positionsByAddress[addr].push(Position({cycleIndex: lastStoredCycleIndex, tokens: amount, exists: true}));

        unchecked {
            positionIndex = positionsByAddress[addr].length - 1;
        }

        IERC20(token).safeTransferFrom(msg.sender, address(this), originalAmount);

        emit Contributed(addr, positionIndex, originalAmount);
    }

    function settleFees() external {
        uint256 _unsettledFees = unsettledFees;

        if (_unsettledFees > 0) {
            unsettledFees = 0;

            uint256 arenaFeeAmount = (_unsettledFees * arenaFee) / arenaAndTopicFee;
            uint256 topicFeeAmount = _unsettledFees - arenaFeeAmount;

            IERC20(token).safeTransfer(ITopic(topicAddress).funds(), topicFeeAmount);
            IERC20(token).safeTransfer(IArena(ITopic(topicAddress).arena()).funds(), arenaFeeAmount);

            emit SettledFees(arenaFeeAmount, topicFeeAmount);
        }
    }

    /// Withdraw the only position
    function withdraw() external singlePosition(msg.sender) {
        withdraw(0);
    }

    /// Transfer the only position
    function transferPosition(address recipient) external singlePosition(msg.sender) {
        transferPosition(recipient, 0);
    }

    /// @param recipient the recipient of all the positions to be transferred.
    /// @param positionIndexes an array of the position indexes that should be transferred.
    /// A position index is the number returned by contribute() when creating the position.
    function transferPositions(address recipient, uint256[] calldata positionIndexes) external {
        uint256 lastIndex;

        unchecked {
            lastIndex = positionIndexes.length - 1;
        }

        for (uint256 i; i <= lastIndex; ) {
            transferPosition(recipient, positionIndexes[i]);
            unchecked {
                ++i;
            }
        }
    }

    /// Split the position equally into numSplits positions.
    function split(uint256 positionIndex, uint256 numSplits) external {
        Position storage position = positionsByAddress[msg.sender][positionIndex];
        split(positionIndex, numSplits - 1, position.tokens / numSplits);
    }

    /// @param positionIndex The positionIndex returned by the contribute() function.
    function checkPosition(
        address addr,
        uint256 positionIndex
    ) public view positionExists(addr, positionIndex) returns (uint256 positionTokens, uint256 shares) {
        (positionTokens, shares) = positionToLastStoredCycle(addr, positionIndex);
        shares += pendingShares(currentCycleNumber(), positionTokens);
    }

    /// @param positionIndex The positionIndex returned by the contribute() function.
    function withdraw(uint256 positionIndex) public positionExists(msg.sender, positionIndex) {
        address addr = msg.sender;

        updateCyclesAddingAmount(0, 0);

        (uint256 positionTokens, uint256 shares) = positionToLastStoredCycle(addr, positionIndex);

        delete positionsByAddress[addr][positionIndex];

        uint256 lastStoredCycleIndex;
        unchecked {
            lastStoredCycleIndex = cycles.length - 1;
            tokens -= positionTokens;
            cycles[lastStoredCycleIndex].shares -= shares;
        }

        IERC20(token).safeTransfer(addr, positionTokens);

        emit Withdrew(addr, positionIndex, positionTokens, shares);
    }

    /// @param positionIndex The positionIndex returned by the contribute() function.
    function transferPosition(
        address recipient,
        uint256 positionIndex
    ) public positionExists(msg.sender, positionIndex) {
        address sender = msg.sender;

        Position[] storage fromPositions = positionsByAddress[sender];
        Position[] storage toPositions = positionsByAddress[recipient];

        toPositions.push(fromPositions[positionIndex]);
        delete fromPositions[positionIndex];

        uint256 recipientPositionIndex;

        unchecked {
            recipientPositionIndex = toPositions.length - 1;
        }

        emit PositionTransferred(sender, recipient, positionIndex, recipientPositionIndex);
    }

    /// Create numSplits new positions each containing amount tokens. Tokens to create the splits will be taken
    /// from the position at positionIndex.
    function split(
        uint256 positionIndex,
        uint256 numSplits,
        uint256 amount
    ) public positionExists(msg.sender, positionIndex) {
        address addr = msg.sender;
        Position[] storage positions = positionsByAddress[addr];
        Position storage position = positions[positionIndex];

        uint256 deductAmount = amount * numSplits;
        if (deductAmount > position.tokens) revert SplitMoreThanAvailable();

        unchecked {
            position.tokens -= deductAmount;
        }

        for (uint256 i = 1; i <= numSplits; ) {
            positions.push(Position({cycleIndex: position.cycleIndex, tokens: amount, exists: true}));
            unchecked {
                ++i;
            }
        }

        uint256 firstNewPositionIndex;

        unchecked {
            firstNewPositionIndex = positions.length - numSplits;
        }

        emit Split(addr, positionIndex, numSplits, firstNewPositionIndex, amount);
    }

    /// @param _tokens The token amount used to compute shares--either from the choice, or an individual position.
    /// @param _cycleNumber The cycle number to compute shares for.
    /// @return The number of shares that have not been added to the last stored cycle.
    /// These will be added to the last stored cycle when updateCyclesAddingAmount() is next called.
    function pendingShares(uint256 _cycleNumber, uint256 _tokens) public view returns (uint256) {
        Cycle storage lastStoredCycle;

        unchecked {
            lastStoredCycle = cycles[cycles.length - 1];
        }

        return (accrualRate * (_cycleNumber - lastStoredCycle.number) * _tokens) / 10000;
    }

    function positionToLastStoredCycle(
        address addr,
        uint256 positionIndex
    ) internal view returns (uint256 positionTokens, uint256 shares) {
        Position storage position = positionsByAddress[addr][positionIndex];

        positionTokens = position.tokens;

        uint256 lastStoredCycleIndex;
        uint256 startIndex;

        unchecked {
            // updateCyclesAddingAmount() will always add a cycle if none exists
            lastStoredCycleIndex = cycles.length - 1;
            startIndex = position.cycleIndex + 1; // can't realistically overflow
        }

        for (uint256 i = startIndex; i <= lastStoredCycleIndex; ) {
            Cycle storage cycle = cycles[i];
            Cycle storage prevStoredCycle = cycles[i - 1];

            shares += (accrualRate * (cycle.number - prevStoredCycle.number) * positionTokens) / 10000;
            uint256 earnedFees = (cycle.fees * shares) / cycle.shares;
            positionTokens += earnedFees;

            unchecked {
                ++i;
            }
        }
    }

    function updateCyclesAddingAmount(uint256 _amount, uint256 _contributorFee) internal {
        uint256 currentCycleNumber_ = currentCycleNumber();

        uint256 length = cycles.length;

        if (length == 0) {
            // Create the first cycle in the array using the first contribution.
            cycles.push(Cycle({number: currentCycleNumber_, shares: 0, fees: 0, hasContributions: true}));
        } else {
            // Not the first contribution.
            uint256 lastStoredCycleIndex;

            unchecked {
                lastStoredCycleIndex = length - 1;
            }

            Cycle storage lastStoredCycle = cycles[lastStoredCycleIndex];
            uint256 lastStoredCycleNumber = lastStoredCycle.number;

            if (lastStoredCycleNumber == currentCycleNumber_) {
                if (lastStoredCycleIndex != 0) {
                    lastStoredCycle.fees += _contributorFee;
                }
            } else {
                // Add a new cycle to the array using values from the previous one.
                Cycle memory newCycle = Cycle({
                    number: currentCycleNumber_,
                    shares: lastStoredCycle.shares +
                        (accrualRate * (currentCycleNumber_ - lastStoredCycleNumber) * tokens) /
                        10000,
                    fees: _contributorFee,
                    hasContributions: _amount > 0
                });
                // We're only interested in adding cycles that have contributions, since we use the stored
                // cycles to compute fees at withdrawal time.
                if (lastStoredCycle.hasContributions) {
                    // Keep cycles with contributions.
                    cycles.push(newCycle); // Push our new cycle in front.
                } else {
                    // If the previous cycle only has withdrawals (no contributions), overwrite it with the current one.
                    cycles[lastStoredCycleIndex] = newCycle;
                }
            } // end else (Add a new cycle...)
        } // end else (Not the first contribution.)
    }
}
