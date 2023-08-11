// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import "./interfaces/ITopic.sol";

struct CycleMetadata {
    uint256 cycle; // cycle number
    uint256 tokens;
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

    CycleMetadata[] public cycles;
    mapping(address => VoteMetadata[]) public userVotes; // users can vote multiple times

    error AlreadyWithdrawn();
    error ZeroAmount();

    constructor(address topic, uint256 feeRateValue, uint256 accrualRateValue) {
        topicAddress = topic;
        feeRate = feeRateValue;
        accrualRate = accrualRateValue;
    }

    function withdraw(uint256 voteIndex) external {
        VoteMetadata storage position = userVotes[msg.sender][voteIndex]; // reverts on invalid index

        if (position.withdrawn) revert AlreadyWithdrawn();
        position.withdrawn = true;
        uint256 tokens = position.tokens;
        uint256 startIndex = position.cycleIndex;
        uint256 shares;

        (uint256 currentCycleIndex, ) = accrue(0);

        for (uint256 i = startIndex + 1; i <= cycles.length; i++) {
            CycleMetadata memory cycle = cycles[i];
            shares +=
                (accrualRate *
                    (cycle.cycle - cycles[startIndex].cycle) *
                    tokens) /
                10000;
            uint256 earnedFees = (cycle.fees * shares) / cycle.shares;
            tokens += earnedFees;
            startIndex = i;
        }

        cycles[currentCycleIndex].tokens -= tokens;
        cycles[currentCycleIndex].shares -= shares;

        // todo: transfer tokens
        // todo: event
    }

    function vote(uint256 amount) external {
        if (amount <= 0) revert ZeroAmount();

        (uint256 currentCycleIndex, uint256 voteAmount) = accrue(amount);

        // record voter metadata
        VoteMetadata[] storage votes = userVotes[msg.sender];
        uint256 length = votes.length;
        if (length == 0 || votes[length - 1].cycleIndex != currentCycleIndex) {
            votes.push(
                VoteMetadata({
                    cycleIndex: currentCycleIndex,
                    tokens: voteAmount,
                    withdrawn: false
                })
            );
        } else {
            votes[length - 1].tokens += voteAmount;
        }

        // todo: transfer in tokens
        // todo: event
    }

    function accrue(
        uint256 amount
    ) internal returns (uint256 cycleIndex, uint256 voteAmount) {
        uint256 currentCycle = ITopic(topicAddress).currentCycle();
        uint256 length = cycles.length;

        if (length == 0) {
            cycles.push(
                CycleMetadata({
                    cycle: currentCycle,
                    tokens: amount,
                    shares: 0,
                    fees: 0,
                    hasVotes: amount > 0
                })
            );

            return (0, amount);
        }

        uint256 fee = (amount * feeRate) / 10000;
        voteAmount = amount - fee;

        CycleMetadata memory lastCycle = cycles[length - 1];

        if (lastCycle.cycle == currentCycle) {
            cycles[length - 1].tokens += voteAmount;
            cycles[length - 1].fees += fee;
            return (length - 1, voteAmount);
        }

        // carry
        CycleMetadata memory newCycle = CycleMetadata({
            cycle: currentCycle,
            tokens: lastCycle.tokens + voteAmount,
            shares: lastCycle.shares +
                (accrualRate *
                    (currentCycle - lastCycle.cycle) *
                    lastCycle.tokens) /
                10000,
            fees: fee,
            hasVotes: voteAmount > 0
        });

        if (!lastCycle.hasVotes) {
            cycles[length - 1] = newCycle;
            return (length - 1, voteAmount);
        } else {
            cycles.push(newCycle);
            return (length, voteAmount);
        }
    }
}
