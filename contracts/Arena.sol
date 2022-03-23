// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./Topic.sol";

contract Arena {
    Topic[] public topics; // topics of this arena

    string public name; // arena name

    address public token; // this is the token that is used to vote in this arena

    uint256 public minContributionAmount; // minimum amount of voting/contributing

    // all percentage fields assume 2 decimal places
    uint16 public maxChoiceFeePercentage; // max percentage of a vote taken as fees for a choice
    uint16 public maxTopicFeePercentage; // max percentage of a vote taken as fees for a topic
    uint16 public arenaFeePercentage; // percentage of each vote that goes to the arena

    uint256 public choiceCreationFee; // to prevent spam choice creation
    uint256 public topicCreationFee; // to prevent spam topic creation

    function info()
        public
        view
        returns (
            string memory, // arena name
            address, // voting token
            uint256, // min contrib amount
            uint16, // max choice funds
            uint16, // max topic funds
            uint16, // arena fee percentage
            uint256, // choice creation fee
            uint256 // topic creation fee
        )
    {
        return (
            name,
            token,
            minContributionAmount,
            maxChoiceFeePercentage,
            maxTopicFeePercentage,
            arenaFeePercentage,
            choiceCreationFee,
            topicCreationFee
        );
    }

    constructor(
        string memory _name,
        address _token,
        uint256 _minContribAmount,
        uint16 _maxChoiceFeePercentage,
        uint16 _maxTopicFeePercentage,
        uint16 _arenaFeePercentage,
        uint256 _choiceCreationFee,
        uint256 _topicCreationFee
    ) {
        require(_arenaFeePercentage <= 100 * 10**2, "Arena fee exceeded 100%");
        name = _name;
        token = _token;
        minContributionAmount = _minContribAmount;
        maxChoiceFeePercentage = _maxChoiceFeePercentage;
        maxTopicFeePercentage = _maxTopicFeePercentage;
        arenaFeePercentage = _arenaFeePercentage;
        choiceCreationFee = _choiceCreationFee;
        topicCreationFee = _topicCreationFee;
    }
}
