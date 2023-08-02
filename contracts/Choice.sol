// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import "./interfaces/ITopic.sol";

struct CycleMetadata {
    uint256 tokens;
    uint256 shares;
    uint256 fees;
    bool exists;
}

struct VoteMetadata {
    uint256 cycle;
    uint256 tokens;
    bool withdrawn; // no partial withdrawal yet
}

contract Choice {
    address public immutable topic;
    uint256 public immutable feeRate; // scale 10000

    uint256 lastVoteOrWithdrawalCycle;

    mapping(uint256 => CycleMetadata) public cycleMetadata; // cycle => CycleMetadata
    mapping(address => VoteMetadata[]) public userVotesMetadata; // user => VoteMetadata[] users can vote multiple times

    constructor(address _topic, uint256 _feeRate) {
        topic = _topic;
        feeRate = _feeRate;
    }

    function withdraw(uint256 _votesMetadataIndex) external {
        VoteMetadata storage voteMetadata_ = userVotesMetadata[msg.sender][
            _votesMetadataIndex
        ]; // reverts on invalid index

        require(
            voteMetadata_.withdrawn == false && voteMetadata_.tokens > 0,
            "You have already withdrawn your tokens"
        );

        uint256 currentCycle_ = ITopic(topic).currentCycle();

        uint256 tokens_ = voteMetadata_.tokens;
        uint256 cycle_ = voteMetadata_.cycle;
        uint256 shares_ = 0;

        for (
            uint256 cycle__ = voteMetadata_.cycle + 1;
            cycle__ <= currentCycle_;
            cycle__++
        ) {
            CycleMetadata storage cycleMetadata_ = cycleMetadata[cycle__];

            if (cycleMetadata_.exists == false) continue; // todo: figoure out a way to avoid this

            shares_ += (cycle__ - cycle_) * tokens_;

            uint256 earnedFees = (cycleMetadata_.fees * shares_) /
                cycleMetadata_.shares;

            tokens_ += earnedFees;
            cycle_ = cycle__;

            cycleMetadata_.tokens -= tokens_;
            cycleMetadata_.shares -= shares_;
        }

        voteMetadata_.withdrawn = true;

        // todo: transfer tokens
        // todo: event
    }

    function vote(uint256 amount) public {
        // todo: transfer in tokens
        uint256 currentCycle_ = ITopic(topic).currentCycle();
        uint256 lastVoteOrWithdrawalCycle_ = lastVoteOrWithdrawalCycle;

        if (currentCycle_ != lastVoteOrWithdrawalCycle_)
            accrue(currentCycle_, lastVoteOrWithdrawalCycle_);

        lastVoteOrWithdrawalCycle = currentCycle_;

        uint256 fee = (amount * feeRate) / 10000;

        CycleMetadata storage cycleMetadata_ = cycleMetadata[currentCycle_];

        cycleMetadata_.tokens += amount;
        cycleMetadata_.fees += fee;

        // record voter metadata
        VoteMetadata[] storage votesMetadata_ = userVotesMetadata[msg.sender];

        if (votesMetadata_.length == 0) {
            votesMetadata_.push(
                VoteMetadata({
                    cycle: currentCycle_,
                    tokens: amount,
                    withdrawn: false
                })
            );
        } else {
            VoteMetadata storage lastVoteMetadata_ = votesMetadata_[
                votesMetadata_.length - 1
            ];

            if (lastVoteMetadata_.cycle == currentCycle_) {
                lastVoteMetadata_.tokens += amount;
            } else {
                votesMetadata_.push(
                    VoteMetadata({
                        cycle: currentCycle_,
                        tokens: amount,
                        withdrawn: false
                    })
                );
            }
        }

        // todo: event
    }

    function accrue(
        uint256 _currentCycle,
        uint256 _lastVoteOrWithdrawalCycle
    ) internal {
        CycleMetadata memory lastCycleMetadata_ = cycleMetadata[
            _lastVoteOrWithdrawalCycle
        ];

        // carry over
        uint256 carryTokens_ = lastCycleMetadata_.tokens;
        uint256 carryShares_ = lastCycleMetadata_.shares;

        uint256 newShares = carryTokens_ *
            (_currentCycle - _lastVoteOrWithdrawalCycle);

        cycleMetadata[_currentCycle] = CycleMetadata({
            tokens: carryTokens_,
            shares: carryShares_ + newShares,
            fees: 0,
            exists: true
        });
    }
}
