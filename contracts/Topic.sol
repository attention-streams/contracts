// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Arena.sol";

contract Topic {
    uint32 public cycleDuration; // share distribution cycle. in terms of # of blocks - ex. once every 100 blocks
    uint16 public sharePerCyclePercentage; // percentage of a position given as "shares" in each cycle

    uint16 public prevContributorsFeePercentage; // percentage of a vote given to the previous voters
    uint16 public topicFundFeePercentage; // percentage of a vote given to the topic

    bool public allowChoiceFunds; // percentage of a vote given to the choice

    uint32 public relativeSupportThreshold; // min support a choice needs to be eligible for external funding
    uint32 public fundingPeriod; // how often funds are distributed to leading choices, in terms of # of cycles. ignored if no external funding available
    uint16 public fundingPercentage; // percentage of funds transferred to leading choices
    bool public hasExternalFunding; // if topic supports external funding for it's choices

    constructor(address arenaAddress) {}
}
