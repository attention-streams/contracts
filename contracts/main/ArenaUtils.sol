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
    uint256 totalSum; // sum of all tokens invested in this cycle
    uint256 generatedFees; // total fees generated in this cycle
    uint256 deductibleSum;
    uint256 paidFees;
}

struct Withdraw {
    uint256 cycle;
    uint256 tokens;
    uint256 fees;
    uint256 shares;
    uint256 paidShares;
}

struct ChoiceVoteData {
    uint256 totalSum; // sum of all tokens invested in this choice
    uint256 firstCycle; // cycle of the first vote
    uint256 totalFeesPaid;
    uint256 totalSharesPaid;
    mapping(uint256 => Cycle) cycles; // cycleId => cycle info
    mapping(uint256 => Withdraw[]) withdrawals; // cycleId => listOf withdrawals
}

struct Choice {
    string description;
    address payable funds; // fees are paid to this address
    uint16 feePercentage; // fees paid to choice from votes
    uint256 fundingTarget; // cannot receive funds more than this amount
    string metaDataUrl;
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
    string metaDataUrl;
}

struct PositionData {
    mapping(address => mapping(uint256 => mapping(uint256 => Position[]))) positions; // positions of each user in each choice of each topic // address => (topicId => (choiceId => Position[]))
    mapping(address => mapping(uint256 => mapping(uint256 => uint256))) positionsLength; // address => (topicId => (choiceId => positions length))
    mapping(address => mapping(uint256 => mapping(uint256 => uint256))) nextClaimIndex;
    mapping(address => mapping(uint256 => mapping(uint256 => uint256))) nextPositionToWithdraw; // address => (topicId => (choiceId => next position to withdraw))
}

struct ChoiceData {
    mapping(uint256 => Choice[]) topicChoices; // list of choices of each topic
    mapping(uint256 => mapping(uint256 => ChoiceVoteData)) choiceVoteData; // topicId => choiceId => aggregated vote data
    mapping(uint256 => mapping(uint256 => bool)) isChoiceDeleted; // topicId => choiceId => isDeleted
}

struct TopicData {
    Topic[] topics;
    mapping(uint256 => bool) isTopicDeleted; // indicates if a topic is deleted or not. (if deleted, not voting can happen)
}
struct FeeData {
    Topic topic;
    Cycle cycle;
    uint256[] deductibleSum;
    uint256[] deductiblShares;
    uint256[] deductibleFees;
    uint256[] cycleShares;
    uint256[] cycleSharesPaid;
    uint256[] cycleFeesEarned;
}

library TopicUtils {
    function getShare(Topic memory topic, uint256 amount)
        internal
        pure
        returns (uint256)
    {
        return (amount * topic.sharePerCyclePercentage) / 1e4;
    }
}

library FeeUtils {
    function getArenaFee(ArenaInfo memory info, uint256 amount)
        internal
        pure
        returns (uint256)
    {
        return (amount * info.arenaFeePercentage) / 10000;
    }

    function getTopicFee(Topic memory topic, uint256 amount)
        internal
        pure
        returns (uint256)
    {
        return (amount * topic.topicFeePercentage) / 10000;
    }

    function getChoiceFee(Choice memory choice, uint256 amount)
        internal
        pure
        returns (uint256)
    {
        return (amount * choice.feePercentage) / 10000;
    }

    function getPrevFee(Topic memory topic, uint256 amount)
        internal
        pure
        returns (uint256)
    {
        return (amount * topic.prevContributorsFeePercentage) / 10000;
    }
}
