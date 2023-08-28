// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/ITopic.sol";

    struct Cycle {
        uint256 number;
        uint256 shares;
        uint256 fees;
        bool hasContributions;
    }

    struct Contribution {
        uint256 cycleIndex;
        uint256 tokens;
        bool exists;
    }

contract Choice {
    using SafeERC20 for IERC20;

    address public immutable topicAddress;
    uint256 public immutable contributorFee; // scale 10000
    uint256 public immutable accrualRate; // scale 10000

    address public immutable token; // contribution token

    // The total number of tokens in this Choice. This should equal balanceOf(address(this)), but we don't want to have
    // to repeatedly call the token contract, so we keep track internally.
    uint256 public tokens;

    Cycle[] public cycles;

    // Addresses can contribute multiple times to the same choice, so the value is an array of Contributions.
    // The index of a Contribution in this array is used in checkPosition(), withdraw(), splitPosition(),
    // mergePositions(), and transferPositions() and is returned by contribute().
    mapping(address => Contribution[]) public positionsByAddress;

    event Withdrew(address indexed addr, uint256 positionIndex, uint256 tokens, uint256 shares);
    event Contributed(address indexed addr, uint256 positionIndex, uint256 tokens);

    error PositionDoesNotExist();
    error NotOnlyPosition();

    constructor(address topic) {
        topicAddress = topic;
        contributorFee = ITopic(topic).contributorFee();
        accrualRate = ITopic(topic).accrualRate();
        token = ITopic(topic).token();
    }

    /// @return The number of shares all contributors hold in this choice.
    /// The total shares can be compared between two choices to see which has more support.
    function totalShares() external view returns (uint256) {
        return cycles[cycles.length - 1].shares + pendingShares(tokens);
    }

    /// Check the number of tokens and shares for an address with only one position.
    function checkPosition(address addr) external view returns (uint256 positionTokens, uint256 shares) {
        uint256 numPositions = positionsByAddress[addr].length;

        if(numPositions == 1){
            return checkPosition(addr, 0);
        }

        if (numPositions > 1) {
            revert NotOnlyPosition();
        }

        revert PositionDoesNotExist();
    }

    /// @return positionIndex will be reused as input to withdraw(), checkPosition(), split() and merge().
    function contribute(uint256 amount) external returns (uint256 positionIndex) {
        address addr = msg.sender;
        uint256 originalAmount = amount;

        tokens += amount;
        updateCyclesAddingAmount(amount);

        uint256 lastStoredCycleIndex;

        unchecked {
            // updateCyclesAddingAmount() will always add a cycle if none exists
            lastStoredCycleIndex = cycles.length - 1;

            if (lastStoredCycleIndex > 0) {
                // Contributor fees are only charged in cycles after the one in which the first contribution was made.
                amount -= amount * contributorFee / 10000;
            }
        }

        positionsByAddress[addr].push(
            Contribution({
                cycleIndex: lastStoredCycleIndex,
                tokens: amount,
                exists: true
            })
        );

        unchecked {
            positionIndex = positionsByAddress[addr].length - 1;
        }

        IERC20(topicAddress).safeTransferFrom(addr, address(this), originalAmount);

        emit Contributed(addr, positionIndex, originalAmount);
    }

    /// Withdraw only position
    function withdraw() external {
        uint256 numPositions = positionsByAddress[msg.sender].length;

        if(numPositions == 1){
            withdraw(0);
        } else if (numPositions > 1) {
            revert NotOnlyPosition();
        }

        revert PositionDoesNotExist();
    }

    /// @param positionIndex The positionIndex returned by the contribute() function.
    function checkPosition(
        address addr,
        uint256 positionIndex
    ) public view returns (uint256 positionTokens, uint256 shares) {
        (positionTokens, shares) = positionToLastStoredCycle(addr, positionIndex);
        shares += pendingShares(positionTokens);
    }

    /// @param positionIndex The positionIndex returned by the contribute() function.
    function withdraw(uint256 positionIndex) public {
        address addr = msg.sender;

        updateCyclesAddingAmount(0);

        (uint256 positionTokens, uint256 shares) = positionToLastStoredCycle(addr, positionIndex);

        delete positionsByAddress[addr][positionIndex];

        uint256 lastStoredCycleIndex;
        unchecked {
            lastStoredCycleIndex = cycles.length - 1;
            tokens -= positionTokens;
            cycles[lastStoredCycleIndex].shares -= shares;
        }

        IERC20(topicAddress).safeTransfer(addr, positionTokens);

        emit Withdrew(addr, positionIndex, positionTokens, shares);
    }

    /// @param _tokens The total number of tokens--either from the choice, or an individual position.
    /// @return The number of shares that have not been added to the last stored cycle.
    /// These will be added to the last stored cycle when updateCyclesAddingAmount() is next called.
    function pendingShares(uint256 _tokens) internal view returns (uint256) {
        uint256 currentCycleNumber = ITopic(topicAddress).currentCycleNumber();

        Cycle storage lastStoredCycle;

        unchecked {
          lastStoredCycle = cycles[cycles.length - 1];
        }

        return (accrualRate * (currentCycleNumber - lastStoredCycle.number) * _tokens) / 10000;
    }

    function positionToLastStoredCycle(
        address addr,
        uint256 positionIndex
    ) internal view returns (uint256 positionTokens, uint256 shares) {
        Contribution[] storage positions = positionsByAddress[addr];

        unchecked{
            if (positionIndex + 1 > positions.length) revert PositionDoesNotExist();
        }

        Contribution storage position = positions[positionIndex];

        if (!position.exists) revert PositionDoesNotExist();

        positionTokens = position.tokens;

        uint256 lastStoredCycleIndex;
        uint256 startIndex;

        unchecked {
            // updateCyclesAddingAmount() will always add a cycle if none exists
            lastStoredCycleIndex = cycles.length - 1;
            startIndex = position.cycleIndex + 1; // can't realistically overflow
        }

        for (uint256 i = startIndex; i <= lastStoredCycleIndex;) {
            Cycle storage cycle = cycles[i];
            Cycle storage prevStoredCycle = cycles[i - 1];

            shares += accrualRate * (cycle.number - prevStoredCycle.number) * positionTokens / 10000;
            uint256 earnedFees = cycle.fees * shares / cycle.shares;
            positionTokens += earnedFees;

            unchecked {
                ++i;
            }
        }
    }

    function updateCyclesAddingAmount(uint256 amount) internal {
        uint256 currentCycleNumber = ITopic(topicAddress).currentCycleNumber();
        uint256 length = cycles.length;

        if (length == 0) {
            // Create the first cycle in the array using the first contribution.
            cycles.push(
                Cycle({
                    number: currentCycleNumber,
                    shares: 0,
                    fees: 0,
                    hasContributions: true
                })
            );
        } else {
            // Not the first contribution.
            uint256 lastStoredCycleIndex;

            unchecked{
                lastStoredCycleIndex = length - 1;
            }

            Cycle storage lastStoredCycle = cycles[lastStoredCycleIndex];
            uint256 lastStoredCycleNumber = lastStoredCycle.number;

            uint256 fee;

            if (lastStoredCycleIndex > 0) {
                // No contributor fees on the first cycle that has a contribution.
                fee = amount * contributorFee / 10000;
            }

            if (lastStoredCycleNumber == currentCycleNumber) {
                lastStoredCycle.fees += fee;
            } else {
                // Add a new cycle to the array using values from the previous one.
                Cycle memory newCycle = Cycle({
                    number: currentCycleNumber,
                    shares: lastStoredCycle.shares +
                        accrualRate * (currentCycleNumber - lastStoredCycleNumber) * tokens / 10000,
                    fees: fee,
                    hasContributions: amount > 0
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
