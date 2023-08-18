// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import "./interfaces/ITopic.sol";

struct Cycle {
    uint256 cycle; // cycle number
    uint256 shares;
    uint256 fees;
    bool hasVotes;
}

struct Vote {
    uint256 cycleIndex;
    uint256 tokens;
    bool withdrawn; // no partial withdrawal yet
}

contract Choice {
    address public immutable topicAddress;
    uint256 public immutable contributorFee; // scale 10000
    uint256 public immutable accrualRate; // scale 10000

    uint256 public tokens;

    Cycle[] public cycles;
    mapping(address => Vote[]) public userVotes; // addresses can contribute multiple times to the same choice

    error AlreadyWithdrawn();

    constructor(address topic) {
        topicAddress = topic;
        contributorFee = ITopic(topic).contributorFee();
        accrualRate = ITopic(topic).accrualRate();
    }

    function withdraw(uint256 voteIndex) external {
        Vote storage position = userVotes[msg.sender][voteIndex]; // reverts on invalid index

        if (position.withdrawn) revert AlreadyWithdrawn();
        position.withdrawn = true;
        uint256 positionTokens = position.tokens;
        uint256 shares;

        updateCycle(0);
        unchecked {  // updateCycle() will always add a cycle to cycles if none exists
            uint256 currentCycleIndex = cycles.length - 1;
            uint256 startCycle = position.cycleIndex + 1; // can't realistically overflow
        }

        for (uint256 i = startCycle; i <= currentCycleIndex; ) {
            Cycle cycle = cycles[i];
            unchecked {
                Cycle prevCycle = cycles[i - 1];
            }
            shares +=
                (accrualRate *
                    (cycle.cycle - prevCycle.cycle) *
                    positionTokens) /
                10000;
            uint256 earnedFees = (cycle.fees * shares) / cycle.shares;
            positionTokens += earnedFees;

            unchecked {
                ++i;
            }
        }

        tokens -= positionTokens;
        cycles[currentCycleIndex].shares -= shares;

        // todo: transfer tokens
        // todo: event
    }

    function vote(uint256 amount) external {
        updateCycle(amount);
        unchecked {  // updateCycle() will always add a cycle to cycles if none exists
            uint256 currentCycleIndex = cycles.length - 1;

            if (currentCycleIndex > 0) {
                // There are no contributor fees in the cycle where the first contribution was made.
                amount -= amount * contributorFee / 10000;
            }
        }

        Vote[] storage votes = userVotes[msg.sender];

        votes.push(
            VoteMetadata({
                cycleIndex: currentCycleIndex,
                tokens: amount,
                withdrawn: false
            })
        );

        // todo: transfer in tokens
        // todo: event
    }

    function updateCycle(uint256 amount) internal {
        uint256 currentCycleNumber = ITopic(topicAddress).currentCycle();
        int currentCycleIndex = cycles.length - 1;

        if (currentCycleIndex == -1) { // Create the first cycle in the array using the first contribution.
            cycles.push(
                CycleMetadata({
                    cycle: currentCycleNumber,
                    shares: 0,
                    fees: 0,
                    hasVotes: true
                })
            );
            tokens = amount;
        }
        else { // Not the first contribution.

            Cycle currentCycle = cycles[currentCycleIndex];

            uint256 fee;

            if (currentCycleIndex > 0) {  // No contributor fees on the first cycle that has a contribution.
                fee = (amount * contributorFee) / 10000;
            }

            if (currentCycle.cycle == currentCycleNumber) {
                tokens += amount;
                currentCycle.fees += fee;
            } else { // carry
                Cycle memory newCycle = CycleMetadata({
                    cycle: currentCycleNumber,
                    shares: currentCycle.shares +
                (accrualRate * (currentCycleNumber - currentCycle.cycle) * tokens) /
                10000,
                    fees: fee,
                    hasVotes: amount > 0
                });

                tokens += amount;

                // We're only interested in storing cycles that have contributions, since we used the stored
                // cycles to compute fees at withdrawal time.
                if (currentCycle.hasVotes) { // Keep cycles with contributions.
                    cycles.push(newCycle);
                } else {
                    // If the previous cycle only has withdrawals (no contributions), overwrite it with the current one.
                    cycles[currentCycleIndex] = newCycle;
                }
            } // end else (carry)
        } // end else (not the first contribution)
    }
}
