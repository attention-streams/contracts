// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ICrowdFund} from "interfaces/ICrowdFund.sol";

struct Cycle {
    uint256 number;
    uint256 shares;
    uint256 fees;
    bool hasContributions;
}

struct Position {
    uint256 cycleIndex;
    uint256 tokens;
}

contract Idea {
    using SafeERC20 for IERC20;

    ICrowdFund public immutable crowdFund;
    IERC20 public immutable token;
    uint256 public immutable startTime;
    uint256 public immutable cycleLength;
    uint256 public immutable contributorFee;
    uint256 public immutable accrualRate;
    uint256 public immutable percentScale;
    uint256 public immutable minFee;
    uint256 public immutable percentFee;

    /// @notice The total number of tokens in this Choice.
    /// @dev This should equal balanceOf(address(this)),
    /// but we don't want to have to repeatedly call the token contract, so we keep track internally.
    uint256 public tokens;

    Cycle[] public cycles;

    /// Addresses can contribute multiple times to the same choice, so we use an array of Positions.
    /// The index of a Position in this array is used in checkPosition(), withdraw(), split(), and
    /// transferPositions() and is returned by contribute().
    mapping(address => Position[]) public positionsByAddress;

    event Withdrew(address indexed addr, uint256 positionIndex, uint256 amount, uint256 shares, uint256 totalShares);
    event Contributed(address indexed addr, uint256 positionIndex, uint256 amount, uint256 totalShares);
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

    error ContributionLessThanMinFee();
    error PositionDoesNotExist();
    error NotOnlyPosition();
    error SplitAmountSpecifiedMoreThanAvailable();

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

        if (position.tokens == 0) revert PositionDoesNotExist();

        _;
    }

    constructor(uint256 contributorFee_) {
        crowdFund = msg.sender;
        startTime = block.timestamp;

        contributorFee = contributorFee_;

        cycleLength = crowdFund.cycleLength();
        accrualRate = crowdFund.accrualRate();
        token = crowdFund.feeToken();
        percentScale = crowdFund.percentScale();
        minFee = crowdFund.minFee();
        percentFee = crowdFund.percentFee();
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

    /// @return positionIndex will be reused as input to withdraw(), checkPosition(), and other functions
    function contribute(uint256 amount) external returns (uint256 positionIndex) {
        if (amount < minFee) revert ContributionLessThanMinFee();

        address addr = msg.sender;

        // Anti-spam fee
        uint256 fee = max(minFee, amount * percentFee / percentScale);
        amount -= fee;
        tokens += amount;

        uint256 _contributorFee = amount * contributorFee / percentScale;

        updateCyclesAddingAmount(amount, _contributorFee);

        uint256 originalAmount = amount;
        uint256 lastStoredCycleIndex;

        unchecked {
            // updateCyclesAddingAmount() will always add a cycle if none exists
            lastStoredCycleIndex = cycles.length - 1;

            if (lastStoredCycleIndex > 0) {
                // Contributor fees are only charged in cycles after the one in which the first contribution was made.
                amount -= _contributorFee;
            }
        }

        positionsByAddress[addr].push(Position({cycleIndex: lastStoredCycleIndex, tokens: amount}));

        unchecked {
            positionIndex = positionsByAddress[addr].length - 1;
        }

        token.safeTransferFrom(addr, address(this), originalAmount);

        // Burn the anti-spam fee
        token.safeTransferFrom(address(this), address(0), fee);

        emit Contributed(addr, positionIndex, originalAmount, totalShares());
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

    /// @return The number of shares all contributors hold in this choice.
    /// The total shares can be compared between two choices to see which has more support.
    function totalShares() public view returns (uint256) {
        return cycles[cycles.length - 1].shares + pendingShares(currentCycleNumber(), tokens);
    }

    function currentCycleNumber() public view returns (uint256) {
        return (block.timestamp - startTime) / cycleLength;
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

        token.safeTransfer(addr, positionTokens);

        emit Withdrew(addr, positionIndex, positionTokens, shares, totalShares());
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
        if (deductAmount > position.tokens) revert SplitAmountSpecifiedMoreThanAvailable();

        unchecked {
            position.tokens -= deductAmount;
        }

        for (uint256 i = 1; i <= numSplits; ) {
            positions.push(Position({cycleIndex: position.cycleIndex, tokens: amount}));
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

        return (accrualRate * (_cycleNumber - lastStoredCycle.number) * _tokens) / percentScale;
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

            shares += (accrualRate * (cycle.number - prevStoredCycle.number) * positionTokens) / percentScale;
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
                        (accrualRate * (currentCycleNumber_ - lastStoredCycleNumber) * tokens) / percentScale,
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
