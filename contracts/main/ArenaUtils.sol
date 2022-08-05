// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Arena.sol";

struct ArenaInfo {
    string name; // arena name
    address token; // this is the token that is used to vote in this arena
    uint256 minContributionAmount; // minimum amount of voting/contributing
    // all percentage fields assume 2 decimal places
    uint16 maxChoiceFeePercentage; // max percentage of a vote taken as fees for a choice
    uint16 maxTopicFeePercentage; // max percentage of a vote taken as fees for a topic
    uint16 arenaFeePercentage; // percentage of each vote that goes to the arena
    uint256 choiceCreationFee; // to prevent spam choice creation
    uint256 topicCreationFee; // to prevent spam topic creation
    address payable funds; // arena funds location
}

struct Cycle {
    uint256 totalShares; // some of all shares invested in this cycle
    uint256 totalSharesPaid; // used to efficiently update aggregates
    uint256 totalSum; // sum of all tokens invested in this cycle
    uint256 totalFees; // total fees accumulated on this cycle (to be distributed to voters)
}

struct ChoiceVoteData {
    uint256 totalSum; // sum of all tokens invested in this choice
    uint256 totalShares; // total shares of this choice
    uint256 totalFess; // total fees generated in this choice
    uint256 updatedAt; // block at which data was last updated
    mapping(uint256 => Cycle) cycles; // cycleId => cycle info
}

struct Choice {
    string description;
    address payable funds; // fees are paid to this address
    uint16 feePercentage; // fees paid to choice from votes
    uint256 fundingTarget; // cannot receive funds more than this amount
}
struct Position {
    // share are dynamically calculated as follows
    // tokensInvested * (rate*cyclesInPosition) + checkPointShares
    uint256 tokens; // current number of tokens in position
    uint256 blockNumber; // the last block that user changed it's position
    uint256 checkPointShares; // for history keeping after user changes the amount of tokens in position
}

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