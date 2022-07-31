// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "./Topic.sol";
import "./Choice.sol";

import "hardhat/console.sol";
import "./Position.sol";

struct ArenaInfo {
    string _name; // arena name
    address _token; // this is the token that is used to vote in this arena
    uint256 _minContributionAmount; // minimum amount of voting/contributing
    // all percentage fields assume 2 decimal places
    uint16 _maxChoiceFeePercentage; // max percentage of a vote taken as fees for a choice
    uint16 _maxTopicFeePercentage; // max percentage of a vote taken as fees for a topic
    uint16 _arenaFeePercentage; // percentage of each vote that goes to the arena
    uint256 _choiceCreationFee; // to prevent spam choice creation
    uint256 _topicCreationFee; // to prevent spam topic creation
    address payable _funds; // arena funds location
}

struct UserDept {
    uint256 amount;
    uint256 blockNumber;
}

struct UserPosition {
    uint256 amount;
    uint256 blockNumber;
    uint256 feesPaied;
}

contract Arena is Initializable {
    using PositionUtils for Position;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    ArenaInfo public info;

    Topic[] public topics; // list of topics in arena
    mapping(uint256 => Choice[]) public topicChoices; // list of choices of each topic
    mapping(uint256 => mapping(uint256 => Position)) // aggregated voting data of a chioce
        public choicePositionSummery; // topicId => (choiceId => listOfPositions)
    mapping(uint256 => mapping(uint256 => address[])) public choiceVoters; // list of all voters in a position
    mapping(address => mapping(uint256 => mapping(uint256 => Position))) // position of each user in each choice of each topic
        public positions; // address => (topicId => (choiceId => Position))

    mapping(address => mapping(uint256 => mapping(uint256 => Position[]))) // address => topicId => choiceId
        public userPositions;
    mapping(address => uint256) public balances; // original deposists of users (amount without fee)
    mapping(address => UserDept) public usersDept; // amount of fees paid out to users

    // choice id => accFeePerShare
    mapping(uint256 => uint256) public accFeePerShare; // accumulated fee per share in each choice

    function initialize(ArenaInfo memory _info) public initializer {
        require(
            (_info._arenaFeePercentage) <= 100 * 10**2,
            "Fees exceeded 100%"
        );
        info = _info;
    }

    function getNextTopicId() public view returns (uint256) {
        return topics.length;
    }

    function getNextChoiceIdInTopic(uint256 topicId)
        public
        view
        returns (uint256)
    {
        return topicChoices[topicId].length;
    }

    function addTopic(Topic memory topic) public {
        if (info._topicCreationFee > 0) {
            IERC20Upgradeable(info._token).safeTransferFrom(
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

        topics.push(topic);
    }

    function addChoice(uint256 topicId, Choice memory choice) public {
        require(
            choice._feePercentage <= topics[topicId]._maxChoiceFeePercentage,
            "Fee percentage too high"
        );

        require(
            choice._feePercentage +
                info._arenaFeePercentage +
                topics[topicId]._topicFeePercentage +
                topics[topicId]._prevContributorsFeePercentage <=
                10000,
            "accumulative fees exceeded 100%"
        );
        if (info._choiceCreationFee > 0) {
            IERC20Upgradeable(info._token).safeTransferFrom(
                msg.sender,
                info._funds,
                info._choiceCreationFee
            );
        }

        topicChoices[topicId].push(choice);
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
        IERC20Upgradeable(info._token).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        Topic memory topic = topics[topicId];
        Choice memory choice = topicChoices[topicId][choiceId];
        Position storage choicePosition = choicePositionSummery[topicId][
            choiceId
        ];

        balances[info._funds] += getArenaFee(amount);
        balances[topic._funds] += getTopicFee(topic, amount);
        balances[choice._funds] += getChoiceFee(choice, amount);

        uint256 netVoteAmount = amount -
            (getArenaFee(amount) +
                getTopicFee(topic, amount) +
                getChoiceFee(choice, amount));

        address[] storage _voters = choiceVoters[topicId][choiceId];

        if (choicePosition.getShares(topic) > 0) {
            uint256 prevFee = getPrevFee(topic, amount);
            uint256 totalShares = choicePosition.getShares(topic);
            netVoteAmount -= prevFee;

            choice._accFeePershare = (prevFee * 1e18) / totalShares;

            // pay previouse contributor
            for (uint256 i = 0; i < _voters.length; i++) {
                Position storage thePosition = positions[_voters[i]][topicId][
                    choiceId
                ];
                uint256 fee = (prevFee * thePosition.getShares(topic)) /
                    totalShares;
                thePosition.updatePosition(topic, fee);
                choicePosition.updatePosition(topic, fee);
            }
        }

        if (positions[msg.sender][topicId][choiceId].isEmpty()) {
            _voters.push(msg.sender);
        }

        positions[msg.sender][topicId][choiceId].updatePosition(
            topic,
            netVoteAmount
        );

        userPositions[msg.sender][topicId][choiceId].push(
            Position({
                tokens: netVoteAmount,
                blockNumber: block.number,
                checkPointShares: 0
            })
        );

        choicePosition.updatePosition(topic, netVoteAmount);
    }

    function getVoterPositionOnChoice(
        uint256 topicId,
        uint256 choiceId,
        address voter
    ) public view returns (uint256 tokens, uint256 shares) {
        Position storage _position = positions[voter][topicId][choiceId];
        Position[] memory _positions = userPositions[voter][topicId][choiceId];
        Topic memory _topic = topics[topicId];
        Choice memory _choice = topicChoices[topicId][choiceId];

        uint256 totalAmount;
        uint256 totalShares;
        for (uint16 i = 0; i < _positions.length; i++) {
            totalAmount += _positions[i].tokens;
            totalShares += _positions[i].getShares(_topic);
        }
        // return (totalAmount, totalShares);
        return (_position.tokens, _position.getShares(_topic));
    }

    function getChoicePositionSummery(uint256 topicId, uint256 choiceId)
        public
        view
        returns (uint256 tokens, uint256 shares)
    {
        return (
            choicePositionSummery[topicId][choiceId].tokens,
            choicePositionSummery[topicId][choiceId].getShares(topics[topicId])
        );
    }

    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }
}
