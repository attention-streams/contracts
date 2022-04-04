// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Topic.sol";
import "./Choice.sol";

import "hardhat/console.sol";
import "./Position.sol";

contract Arena {
    mapping(uint256 => Topic) public _topicIdMap; // list of topics in arena
    uint256 public _nextTopicId; // id of a new topic

    // list of choices of each topic
    mapping(uint256 => Choice[]) public _topicChoices;
    // next choice id in each topic
    mapping(uint256 => uint256) public _topicChoiceNextId;

    // topicId => (choiceId => listOfPositions)
    mapping(uint256 => mapping(uint256 => Position)) _choicePositionSummery;

    // position of each user in each choice of each topic
    // address => (topicId => (choiceId => Position))
    mapping(address => mapping(uint256 => mapping(uint256 => Position))) _addressPositions;

    string public _name; // arena name

    IERC20 public _token; // this is the token that is used to vote in this arena

    uint256 public _minContributionAmount; // minimum amount of voting/contributing

    // all percentage fields assume 2 decimal places
    uint16 public _maxChoiceFeePercentage; // max percentage of a vote taken as fees for a choice
    uint16 public _maxTopicFeePercentage; // max percentage of a vote taken as fees for a topic
    uint16 public _arenaFeePercentage; // percentage of each vote that goes to the arena

    uint256 public _choiceCreationFee; // to prevent spam choice creation
    uint256 public _topicCreationFee; // to prevent spam topic creation

    address payable public _funds; // arena funds location

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
            uint256 topicCreationFee,
            address funds
        )
    {
        return (
            _name,
            address(_token),
            _minContributionAmount,
            _maxChoiceFeePercentage,
            _maxTopicFeePercentage,
            _arenaFeePercentage,
            _choiceCreationFee,
            _topicCreationFee,
            _funds
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
        uint256 topicCreationFee,
        address payable funds
    ) {
        require((arenaFeePercentage) <= 100 * 10**2, "Fees exceeded 100%");
        _name = name;
        _token = IERC20(token);
        _minContributionAmount = minContribAmount;
        _maxChoiceFeePercentage = maxChoiceFeePercentage;
        _maxTopicFeePercentage = maxTopicFeePercentage;
        _arenaFeePercentage = arenaFeePercentage;
        _choiceCreationFee = choiceCreationFee;
        _topicCreationFee = topicCreationFee;
        _funds = funds;
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
            uint16 fundingPercentage, // percentage
            address payable funds
        )
    {
        Topic storage t = _topicIdMap[_id];
        return (
            t._id,
            t._cycleDuration,
            t._sharePerCyclePercentage,
            t._prevContributorsFeePercentage,
            t._topicFeePercentage,
            t._maxChoiceFeePercentage,
            t._relativeSupportThreshold,
            t._fundingPeriod,
            t._fundingPercentage,
            t._funds
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
        uint16 fundingPercentage,
        address payable funds
    ) public {
        if (_topicCreationFee > 0) {
            _token.transferFrom(msg.sender, _funds, _topicCreationFee);
        }

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
        _nextTopicId += 1;

        uint256 newTopicId = _nextTopicId;

        Topic memory newTopic = Topic(
            newTopicId,
            cycleDuration,
            sharePerCyclePercentage,
            prevContributorsFeePercentage,
            topicFeePercentage,
            maxChoiceFeePercentage,
            relativeSupportThreshold,
            fundingPeriod,
            fundingPercentage,
            funds
        );
        _topicIdMap[newTopicId] = newTopic;
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
        if (_choiceCreationFee > 0) {
            _token.transferFrom(msg.sender, _funds, _choiceCreationFee);
        }

        require(
            feePercentage <= _topicIdMap[topicId]._maxChoiceFeePercentage,
            "Fee percentage too high"
        );

        require(
            feePercentage +
                _arenaFeePercentage +
                _topicIdMap[topicId]._topicFeePercentage +
                _topicIdMap[topicId]._prevContributorsFeePercentage <=
                10000,
            "accumulative fees exceeded 100%"
        );

        _topicChoiceNextId[topicId] += 1;
        uint256 choiceId = _topicChoiceNextId[topicId];
        Choice memory choice = Choice(
            choiceId,
            description,
            funds,
            feePercentage,
            fundingTarget
        );
        _topicChoices[topicId].push(choice);
    }

    function calculateSharesOfPosition(Position memory p, Topic memory t)
        public
        view
        returns (uint256)
    {
        // cycles passed
        uint256 shares;
        uint256 cyclesPassed = (block.number - p.blockNumber) /
            t._cycleDuration;
        shares =
            p.tokens *
            cyclesPassed *
            (t._sharePerCyclePercentage / 10000) +
            p.checkPointShares;

        return shares;
    }

    function vote(
        uint256 topicId,
        uint256 choiceId,
        uint256 amount
    ) public {
        require(
            amount >= _minContributionAmount,
            "contribution amount too low"
        );

        Position storage _userPosition = _addressPositions[address(msg.sender)][
            topicId
        ][choiceId];

        Position storage _choicePosition = _choicePositionSummery[topicId][
            choiceId
        ];

        // update user postion data
        _userPosition.checkPointShares = calculateSharesOfPosition(
            _userPosition,
            _topicIdMap[topicId]
        );
        _userPosition.tokens += amount;
        _userPosition.blockNumber = block.number;

        // update choice summery position data
        _choicePosition.checkPointShares = calculateSharesOfPosition(
            _userPosition,
            _topicIdMap[topicId]
        );
        _choicePosition.tokens += amount;
        _choicePosition.blockNumber = block.number;
    }

    function getVoterPositionOnChoice(
        uint256 topicId,
        uint256 choiceId,
        address voter
    ) public view returns (uint256 tokens, uint256 shares) {
        Position storage _position = _addressPositions[voter][topicId][
            choiceId
        ];
        return (
            _position.tokens,
            calculateSharesOfPosition(_position, _topicIdMap[topicId])
        );
    }

    function choicePositionSummery(uint256 topicId, uint256 choiceId)
        public
        view
        returns (uint256 tokens, uint256 shares)
    {
        return (
            _choicePositionSummery[topicId][choiceId].tokens,
            calculateSharesOfPosition(
                _choicePositionSummery[topicId][choiceId],
                _topicIdMap[topicId]
            )
        );
    }
}
