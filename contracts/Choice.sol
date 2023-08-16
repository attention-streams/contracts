// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import "./interfaces/ITopic.sol";

import "hardhat/console.sol";

struct CycleMetadata {
    uint256 cycle; // cycle number
    uint256 shares;
    uint256 fees;
    bool hasVotes;
}

struct VoteMetadata {
    uint256 cycleIndex;
    uint256 tokens;
    bool withdrawn; // no partial withdrawal yet
}

contract Choice {
    address public immutable topicAddress;
    uint256 public immutable feeRate; // scale 10000
    uint256 public immutable accrualRate; // scale 10000

    uint256 public tokens;

    CycleMetadata[] public cycles;
    mapping(address => VoteMetadata[]) public userVotes; // users can vote multiple times

    error AlreadyWithdrawn();
    error ZeroAmount();

    constructor(address topic) {
        topicAddress = topic;
        feeRate = ITopic(topic).choiceFeeRate();
        accrualRate = ITopic(topic).accrualRate();
    }

    function withdraw(uint256 voteIndex) external {
        VoteMetadata storage position = userVotes[msg.sender][voteIndex]; // reverts on invalid index

        if (position.withdrawn) revert AlreadyWithdrawn();
        position.withdrawn = true;
        uint256 positionTokens = position.tokens;
        uint256 shares;

        (uint256 currentCycleIndex, ) = updateCycle(0);
        uint256 len = cycles.length;
        for (uint256 i = position.cycleIndex + 1; i < len; ) {
            CycleMetadata memory cycle = cycles[i];
            shares +=
                (accrualRate *
                    (cycle.cycle - cycles[i - 1].cycle) *
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
        if (amount <= 0) revert ZeroAmount();

        uint256 currentCycleIndex;

        // cast the vote
        if (cycles.length == 0) {
            cycles.push(
                CycleMetadata({
                    cycle: ITopic(topicAddress).currentCycle(),
                    shares: 0,
                    fees: 0,
                    hasVotes: true
                })
            );
            tokens = amount;
        } else {
            uint256 fee;
            (currentCycleIndex, fee) = updateCycle(amount);
            amount -= fee;
        }

        // record voter metadata
        VoteMetadata[] storage votes = userVotes[msg.sender];
        uint256 length = votes.length;
        if (length == 0 || votes[length - 1].cycleIndex != currentCycleIndex) {
            votes.push(
                VoteMetadata({
                    cycleIndex: currentCycleIndex,
                    tokens: amount,
                    withdrawn: false
                })
            );
        } else {
            votes[length - 1].tokens += amount;
        }

        // todo: transfer in tokens
        // todo: event
    }

    function updateCycle(
        uint256 amount
    ) internal returns (uint256 cycleIndex, uint256 fee) {
        uint256 currentCycle = ITopic(topicAddress).currentCycle();
        cycleIndex = cycles.length - 1;
        CycleMetadata memory lastCycle = cycles[cycleIndex];

        if (lastCycle.cycle > 0) {
            fee = (amount * feeRate) / 10000;
        }

        if (lastCycle.cycle == currentCycle) {
            tokens += amount;
            cycles[cycleIndex].fees = lastCycle.fees + fee;
        } else {
            // carry
            CycleMetadata memory newCycle = CycleMetadata({
                cycle: currentCycle,
                shares: lastCycle.shares +
                    (accrualRate * (currentCycle - lastCycle.cycle) * tokens) /
                    10000,
                fees: fee,
                hasVotes: amount > 0
            });

            tokens += amount;

            if (lastCycle.hasVotes) {
                cycles.push(newCycle);
                unchecked {
                    ++cycleIndex;
                }
            } else {
                cycles[cycleIndex] = newCycle;
            }
        }
    }
}
