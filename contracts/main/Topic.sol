// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Choice.sol";

struct Topic {
    uint256 _id;
    uint32 _cycleDuration; // share distribution cycle. in terms of # of blocks - ex. once every 100 blocks
    uint16 _sharePerCyclePercentage; // percentage of a position given as "shares" in each cycle
    uint16 _prevContributorsFeePercentage; // percentage of a vote given to the previous voters
    uint16 _topicFeePercentage; // percentage of a vote given to the topic
    uint16 _maxChoiceFeePercentage; // percentage of a vote given to the choice
    uint32 _relativeSupportThreshold; // min support a choice needs to be eligible for external funding
    uint32 _fundingPeriod; // how often funds are distributed to leading choices, in terms of # of cycles. ignored if no external funding available
    uint16 _fundingPercentage; // percentage of funds transferred to leading choices
}
