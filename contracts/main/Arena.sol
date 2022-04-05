// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Topic.sol";
import "./Choice.sol";

import "hardhat/console.sol";
import "./Position.sol";

struct ArenaInfo {
    string _name; // arena name
    IERC20 _token; // this is the token that is used to vote in this arena
    uint256 _minContributionAmount; // minimum amount of voting/contributing
    // all percentage fields assume 2 decimal places
    uint16 _maxChoiceFeePercentage; // max percentage of a vote taken as fees for a choice
    uint16 _maxTopicFeePercentage; // max percentage of a vote taken as fees for a topic
    uint16 _arenaFeePercentage; // percentage of each vote that goes to the arena
    uint256 _choiceCreationFee; // to prevent spam choice creation
    uint256 _topicCreationFee; // to prevent spam topic creation
    address payable _funds; // arena funds location
}

contract Arena {
    using PositionUtils for Position;

    ArenaInfo public _info;
    Topic[] public _topics; // list of topics in arena
    mapping(uint256 => Choice[]) public _topicChoices; // list of choices of each topic
    mapping(uint256 => mapping(uint256 => Position)) // aggregated voting data of a chioce
        public _choicePositionSummery; // topicId => (choiceId => listOfPositions)
    mapping(address => mapping(uint256 => mapping(uint256 => Position))) // position of each user in each choice of each topic
        public _addressPositions; // address => (topicId => (choiceId => Position))
    mapping(address => uint256) public claimableBalance; // amount of "_info._token" that an address can withdraw from the arena

    constructor(
        string memory name,
        address token,
        uint256 minContribAmount,
        uint16 maxChoiceFeePercentage,
        uint16 maxTopicFeePercentage,
        uint16 arenaFeePercentage,
        uint256 choiceCreationFee,
        uint256 topicCreationFee,
        address payable funds
    ) {
        require((arenaFeePercentage) <= 100 * 10**2, "Fees exceeded 100%");
        _info._name = name;
        _info._token = IERC20(token);
        _info._minContributionAmount = minContribAmount;
        _info._maxChoiceFeePercentage = maxChoiceFeePercentage;
        _info._maxTopicFeePercentage = maxTopicFeePercentage;
        _info._arenaFeePercentage = arenaFeePercentage;
        _info._choiceCreationFee = choiceCreationFee;
        _info._topicCreationFee = topicCreationFee;
        _info._funds = funds;
    }

    function _nextTopicId() public view returns (uint256) {
        return _topics.length;
    }

    function _nextChoiceIdInTopic(uint256 topicId)
        public
        view
        returns (uint256)
    {
        return _topicChoices[topicId].length;
    }

    function info() public view returns (ArenaInfo memory) {
        return _info;
    }

    function getTopicInfoById(uint256 _id) public view returns (Topic memory) {
        return _topics[_id];
    }

    function addTopic(Topic memory topic) public {
        if (_info._topicCreationFee > 0) {
            _info._token.transferFrom(
                msg.sender,
                _info._funds,
                _info._topicCreationFee
            );
        }

        require(
            topic._fundingPercentage <= 10000,
            "funding percentage exceeded 100%"
        );

        require(
            topic._topicFeePercentage <= _info._maxTopicFeePercentage,
            "Max topic fee exceeded"
        );
        require(
            topic._maxChoiceFeePercentage <= _info._maxChoiceFeePercentage,
            "Max choice fee exceeded"
        );
        require(
            _info._arenaFeePercentage +
                topic._topicFeePercentage +
                topic._prevContributorsFeePercentage <=
                10000,
            "accumulative fees exceeded 100%"
        );

        topic._id = _topics.length;
        _topics.push(topic);
    }

    function choiceInfo(uint256 topicId, uint256 choiceId)
        public
        view
        returns (
            uint256 id,
            string memory description,
            address funds, // fees are paid to this address
            uint16 feePercentage, // fees paid to choice from votes
            uint256 fundingTarget
        )
    {
        Choice storage c = _topicChoices[topicId][choiceId];
        return (
            c._id,
            c._description,
            c._funds,
            c._feePercentage,
            c._fundingTarget
        );
    }

    function addChoice(
        uint256 topicId,
        string memory description,
        address payable funds,
        uint16 feePercentage,
        uint256 fundingTarget
    ) public {
        if (_info._choiceCreationFee > 0) {
            _info._token.transferFrom(
                msg.sender,
                _info._funds,
                _info._choiceCreationFee
            );
        }

        require(
            feePercentage <= _topics[topicId]._maxChoiceFeePercentage,
            "Fee percentage too high"
        );

        require(
            feePercentage +
                _info._arenaFeePercentage +
                _topics[topicId]._topicFeePercentage +
                _topics[topicId]._prevContributorsFeePercentage <=
                10000,
            "accumulative fees exceeded 100%"
        );

        Choice memory choice = Choice(
            _topicChoices[topicId].length,
            description,
            funds,
            feePercentage,
            fundingTarget
        );
        _topicChoices[topicId].push(choice);
    }

    function vote(
        uint256 topicId,
        uint256 choiceId,
        uint256 amount
    ) public {
        require(
            amount >= _info._minContributionAmount,
            "contribution amount too low"
        );
        _info._token.transferFrom(msg.sender, address(this), amount);

        Topic memory topic = _topics[topicId];
        Choice memory choice = _topicChoices[topicId][choiceId];

        // pay arena, topic, and choice fees
        claimableBalance[address(_info._funds)] +=
            (amount * _info._arenaFeePercentage) /
            10000;
        claimableBalance[address(topic._funds)] +=
            (amount * topic._topicFeePercentage) /
            10000;
        claimableBalance[address(choice._funds)] +=
            (amount * choice._feePercentage) /
            10000;

        _addressPositions[msg.sender][topicId][choiceId].updatePosition(
            topic,
            amount
        );

        _choicePositionSummery[topicId][choiceId].updatePosition(topic, amount);
    }

    function getVoterPositionOnChoice(
        uint256 topicId,
        uint256 choiceId,
        address voter
    ) public view returns (uint256 tokens, uint256 shares) {
        Position storage _position = _addressPositions[voter][topicId][
            choiceId
        ];
        return (_position.tokens, _position.getShares(_topics[topicId]));
    }

    function choicePositionSummery(uint256 topicId, uint256 choiceId)
        public
        view
        returns (uint256 tokens, uint256 shares)
    {
        return (
            _choicePositionSummery[topicId][choiceId].tokens,
            _choicePositionSummery[topicId][choiceId].getShares(
                _topics[topicId]
            )
        );
    }

    function balanceOf(address account) public view returns (uint256) {
        return claimableBalance[account];
    }
}
