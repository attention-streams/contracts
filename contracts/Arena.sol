// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract Arena {
    string public name;             // arena name
    address public token;                  // this is the token that is used to vote in this arena
    uint256 public minContributionAmount;  // minimum amount of voting/contributing
    bool public allowChoiceFunds;   // can choices receive funding from votes
    bool public allowTopicFunds;    // can topics receive funding from votes
    uint8 public arenaFeePercentage; // percentage of each vote that goes to the arena
    uint256 public choiceCreationFee;  // to prevent spam choice creation
    uint256 public topicCreationFee;   // to prevent spam topic creation

    function info() public view returns(
        string memory, address, uint256,
        bool, bool, uint, uint256, uint256
    ) {
        return (name,token, minContributionAmount,
                allowTopicFunds, allowTopicFunds, arenaFeePercentage,
        choiceCreationFee,topicCreationFee);
    }

    constructor(
        string memory _name,
        address _token,
        uint256 _minContribAmount,
        bool _allowChoiceFunds,
        bool _allowTopicFunds,
        uint8 _arenaFeePercentage,
        uint256 _choiceCreationFee,
        uint256 _topicCreationFee
    ) {
        require(_arenaFeePercentage <= 100);
        name = _name;
        token = _token;
        minContributionAmount = _minContribAmount;
        allowChoiceFunds = _allowChoiceFunds;
        allowTopicFunds = _allowTopicFunds;
        arenaFeePercentage = _arenaFeePercentage;
        choiceCreationFee = _choiceCreationFee;
        topicCreationFee = _topicCreationFee;
    }
}
