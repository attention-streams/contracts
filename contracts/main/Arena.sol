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

    ArenaInfo public info;

    Topic[] internal _topics; // list of topics in arena
    mapping(uint256 => Choice[]) internal _topicChoices; // list of choices of each topic
    mapping(uint256 => mapping(uint256 => Position)) // aggregated voting data of a chioce
        internal _choicePositionSummery; // topicId => (choiceId => listOfPositions)
    mapping(uint256 => mapping(uint256 => address[])) internal _choiceVoters; // list of all voters in a position
    mapping(address => mapping(uint256 => mapping(uint256 => Position))) // position of each user in each choice of each topic
        internal _addressPositions; // address => (topicId => (choiceId => Position))
    mapping(address => uint256) internal claimableBalance; // amount of "info._token" that an address can withdraw from the arena

    constructor(ArenaInfo memory _info) {
        require(
            (_info._arenaFeePercentage) <= 100 * 10**2,
            "Fees exceeded 100%"
        );
        info = _info;
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

    function getTopicInfoById(uint256 _id) public view returns (Topic memory) {
        return _topics[_id];
    }

    function addTopic(Topic memory topic) public {
        if (info._topicCreationFee > 0) {
            info._token.transferFrom(
                msg.sender,
                info._funds,
                info._topicCreationFee
            );
        }

        require(
            topic._fundingPercentage <= 10000,
            "funding percentage exceeded 100%"
        );

        require(
            topic._topicFeePercentage <= info._maxTopicFeePercentage,
            "Max topic fee exceeded"
        );
        require(
            topic._maxChoiceFeePercentage <= info._maxChoiceFeePercentage,
            "Max choice fee exceeded"
        );
        require(
            info._arenaFeePercentage +
                topic._topicFeePercentage +
                topic._prevContributorsFeePercentage <=
                10000,
            "accumulative fees exceeded 100%"
        );

        _topics.push(topic);
    }

    function choiceInfo(uint256 topicId, uint256 choiceId)
        public
        view
        returns (Choice memory)
    {
        return _topicChoices[topicId][choiceId];
    }

    function addChoice(uint256 topicId, Choice memory choice) public {
        if (info._choiceCreationFee > 0) {
            info._token.transferFrom(
                msg.sender,
                info._funds,
                info._choiceCreationFee
            );
        }

        require(
            choice._feePercentage <= _topics[topicId]._maxChoiceFeePercentage,
            "Fee percentage too high"
        );

        require(
            choice._feePercentage +
                info._arenaFeePercentage +
                _topics[topicId]._topicFeePercentage +
                _topics[topicId]._prevContributorsFeePercentage <=
                10000,
            "accumulative fees exceeded 100%"
        );
        _topicChoices[topicId].push(choice);
    }

    function getArenaFee(uint256 amount) internal view returns (uint256) {
        return (amount * info._arenaFeePercentage) / 10000;
    }

    function getTopicFee(Topic memory topic, uint256 amount)
        internal
        pure
        returns (uint256)
    {
        return (amount * topic._topicFeePercentage) / 10000;
    }

    function getChoiceFee(Choice memory choice, uint256 amount)
        internal
        pure
        returns (uint256)
    {
        return (amount * choice._feePercentage) / 10000;
    }

    function getPrevFee(Topic memory topic, uint256 amount)
        internal
        pure
        returns (uint256)
    {
        return (amount * topic._prevContributorsFeePercentage) / 10000;
    }

    function vote(
        uint256 topicId,
        uint256 choiceId,
        uint256 amount
    ) public {
        require(
            amount >= info._minContributionAmount,
            "contribution amount too low"
        );
        info._token.transferFrom(msg.sender, address(this), amount);

        Topic memory topic = _topics[topicId];
        Choice memory choice = _topicChoices[topicId][choiceId];
        Position storage choicePosition = _choicePositionSummery[topicId][
            choiceId
        ];
        uint256 netVoteAmount;

        claimableBalance[info._funds] += getArenaFee(amount);
        claimableBalance[topic._funds] += getTopicFee(topic, amount);
        claimableBalance[choice._funds] += getChoiceFee(choice, amount);

        netVoteAmount =
            amount -
            (getArenaFee(amount) +
                getTopicFee(topic, amount) +
                getChoiceFee(choice, amount));

        if (choicePosition.getShares(topic) > 0) {
            uint256 prevFee = getPrevFee(topic, amount);
            uint256 totalShares = choicePosition.getShares(topic);
            netVoteAmount -= prevFee;

            // pay previouse contributor
            for (
                uint256 i = 0;
                i < _choiceVoters[topicId][choiceId].length;
                i++
            ) {
                Position storage thePosition = _addressPositions[
                    _choiceVoters[topicId][choiceId][i]
                ][topicId][choiceId];
                if (thePosition.blockNumber >= block.number) continue; // ignore if does not belong to prev cycles
                uint256 fee = (prevFee * thePosition.getShares(topic)) /
                    totalShares;
                thePosition.updatePosition(topic, fee);
                choicePosition.updatePosition(topic, fee);
            }
        }

        _addressPositions[msg.sender][topicId][choiceId].updatePosition(
            topic,
            netVoteAmount
        );

        _choicePositionSummery[topicId][choiceId].updatePosition(
            topic,
            netVoteAmount
        );

        _choiceVoters[topicId][choiceId].push(msg.sender);
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
