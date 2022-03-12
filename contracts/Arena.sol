// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract Arena {
    string public name;             // arena name
    string public description;      // overall description of the arena
    string[] public rules;          // rules governing the arena
    address public token;                  // this is the token that is used to vote in this arena
    uint256 public minContributionAmount;  // minimum amount of voting/contributing
    bool public allowChoiceFunds;   // can choices receive funding from votes
    bool public allowTopicFunds;    // can topics receive funding from votes
    uint public arenaFeePercentage; // percentage of each vote that goes to the arena
    uint256 public choiceCreationFee;  // to prevent spam choice creation
    uint256 public topicCreationFee;   // to prevent spam topic creation
    string[] public tags;

    function info() public view returns(
        string memory, string memory,
        string[] memory, address, uint256,
        bool, bool, uint, uint256, uint256,
        string[] memory
    ) {
        return (name, description, rules, token, minContributionAmount,
                allowTopicFunds, allowTopicFunds, arenaFeePercentage,
        choiceCreationFee,topicCreationFee,tags);
    }

    constructor(
        string memory _name,
        string memory _description,
        string[] memory _rules,
        address _token,
        uint256 _minContribAmount,
        bool _allowChoiceFunds,
        bool _allowTopicFunds,
        uint _arenaFeePercentage,
        uint256 _choiceCreationFee,
        uint256 _topicCreationFee,
        string[] memory _tags
    ) {
        name = _name;
        description = _description;
        rules = _rules;
        token = _token;
        minContributionAmount = _minContribAmount;
        allowChoiceFunds = _allowChoiceFunds;
        allowTopicFunds = _allowTopicFunds;
        arenaFeePercentage = _arenaFeePercentage;
        choiceCreationFee = _choiceCreationFee;
        topicCreationFee = _topicCreationFee;
        tags = _tags;
    }
}
