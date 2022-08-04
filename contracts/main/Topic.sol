// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

struct Topic {
    uint32 cycleDuration; // share distribution cycle. in terms of # of blocks - ex. once every 100 blocks
    uint32 startBlock; // block to open voting
    uint16 sharePerCyclePercentage; // percentage of a position given as "shares" in each cycle
    uint16 prevContributorsFeePercentage; // percentage of a vote given to the previous voters
    uint16 topicFeePercentage; // percentage of a vote given to the topic
    uint16 maxChoiceFeePercentage; // percentage of a vote given to the choice
    uint32 relativeSupportThreshold; // min support a choice needs to be eligible for external funding
    uint32 fundingPeriod; // how often funds are distributed to leading choices, in terms of # of cycles. ignored if no external funding available
    uint16 fundingPercentage; // percentage of funds transferred to leading choices
    address payable funds;
}
