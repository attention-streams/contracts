// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./Topic.sol";

contract Arena {
    struct TopicData {
        mapping(uint256 => Topic) topicIdMap;
        uint256 nextTopicId;
    }

    TopicData public _topicData;

    string public _name; // arena name

    address public _token; // this is the token that is used to vote in this arena

    uint256 public _minContributionAmount; // minimum amount of voting/contributing

    // all percentage fields assume 2 decimal places
    uint16 public _maxChoiceFeePercentage; // max percentage of a vote taken as fees for a choice
    uint16 public _maxTopicFeePercentage; // max percentage of a vote taken as fees for a topic
    uint16 public _arenaFeePercentage; // percentage of each vote that goes to the arena

    uint256 public _choiceCreationFee; // to prevent spam choice creation
    uint256 public _topicCreationFee; // to prevent spam topic creation

    function info()
        public
        view
        returns (
            string memory name,
            address token,
            uint256 minContribAmount,
            uint16 maxChoiceFeePercentage,
            uint16 maxTopicFeePercentage,
            uint16 arenaFeePercentage,
            uint256 choiceCreationFee,
            uint256 topicCreationFee
        )
    {
        return (
            _name,
            _token,
            _minContributionAmount,
            _maxChoiceFeePercentage,
            _maxTopicFeePercentage,
            _arenaFeePercentage,
            _choiceCreationFee,
            _topicCreationFee
        );
    }

    constructor(
        string memory name,
        address token,
        uint256 minContribAmount,
        uint16 maxChoiceFeePercentage,
        uint16 maxTopicFeePercentage,
        uint16 arenaFeePercentage,
        uint256 choiceCreationFee,
        uint256 topicCreationFee
    ) {
        require((arenaFeePercentage) <= 100 * 10**2, "Fees exceeded 100%");
        _name = name;
        _token = token;
        _minContributionAmount = minContribAmount;
        _maxChoiceFeePercentage = maxChoiceFeePercentage;
        _maxTopicFeePercentage = maxTopicFeePercentage;
        _arenaFeePercentage = arenaFeePercentage;
        _choiceCreationFee = choiceCreationFee;
        _topicCreationFee = topicCreationFee;
    }

    function getTopicInfoById(uint256 _id)
        public
        view
        returns (
            uint256 id,
            uint32 cycleDuration, // share distribution cycle. in terms of # of blocks - ex. once every 100 blocks
            uint16 sharePerCyclePercentage, // percentage of a position given as "shares" in each cycle
            uint16 prevContributorsFeePercentage, // percentage of a vote given to the previous voters
            uint16 topicFeePercentage, // percentage of a vote given to the topic
            uint16 maxChoiceFeePercentage, // percentage of a vote given to the choice
            uint32 relativeSupportThreshold, // min support a choice needs to be eligible for external funding
            uint32 fundingPeriod, // how often funds are distributed to leading choices, in terms of # of cycles. ignored if no external funding available
            uint16 fundingPercentage // percentage
        )
    {
        Topic memory t = _topicData.topicIdMap[_id];
        return (
            t._id,
            t._cycleDuration,
            t._sharePerCyclePercentage,
            t._prevContributorsFeePercentage,
            t._topicFeePercentage,
            t._maxChoiceFeePercentage,
            t._relativeSupportThreshold,
            t._fundingPeriod,
            t._fundingPercentage
        );
    }

    function addTopic(
        uint32 cycleDuration,
        uint16 sharePerCyclePercentage,
        uint16 prevContributorsFeePercentage,
        uint16 topicFeePercentage,
        uint16 maxChoiceFeePercentage,
        uint32 relativeSupportThreshold,
        uint32 fundingPeriod,
        uint16 fundingPercentage
    ) public {
        require(fundingPercentage <= 10000, "funding percentage exceeded 100%");
        require(
            topicFeePercentage <= _maxTopicFeePercentage,
            "Max topic fee exceeded"
        );
        require(
            maxChoiceFeePercentage <= _maxChoiceFeePercentage,
            "Max choice fee exceeded"
        );
        require(
            _arenaFeePercentage +
                topicFeePercentage +
                prevContributorsFeePercentage <=
                10000,
            "accumulative fees exceeded 100%"
        );
        _topicData.nextTopicId += 1;
        uint256 newTopicId = _topicData.nextTopicId;

        Topic memory newTopic = Topic(
            newTopicId,
            cycleDuration,
            sharePerCyclePercentage,
            prevContributorsFeePercentage,
            topicFeePercentage,
            maxChoiceFeePercentage,
            relativeSupportThreshold,
            fundingPeriod,
            fundingPercentage
        );
        _topicData.topicIdMap[newTopicId] = newTopic;
    }
}
