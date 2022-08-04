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
    mapping(address => uint256) public claimableBalance; // amount of "info._token" that an address can withdraw from the arena

    function initialize(ArenaInfo memory _info) public initializer {
        require(
            (_info.arenaFeePercentage) <= 100 * 10**2,
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
        if (info.topicCreationFee > 0) {
            IERC20Upgradeable(info.token).safeTransferFrom(
                msg.sender,
                info.funds,
                info.topicCreationFee
            );
        }

        require(
            topic.fundingPercentage <= 10000,
            "funding percentage exceeded 100%"
        );

        require(
            topic.topicFeePercentage <= info.maxTopicFeePercentage,
            "Max topic fee exceeded"
        );
        require(
            topic.maxChoiceFeePercentage <= info.maxChoiceFeePercentage,
            "Max choice fee exceeded"
        );
        require(
            info.arenaFeePercentage +
                topic.topicFeePercentage +
                topic.prevContributorsFeePercentage <=
                10000,
            "accumulative fees exceeded 100%"
        );

        topics.push(topic);
    }

    function addChoice(uint256 topicId, Choice memory choice) public {
        require(
            choice.feePercentage <= topics[topicId].maxChoiceFeePercentage,
            "Fee percentage too high"
        );

        require(
            choice.feePercentage +
                info.arenaFeePercentage +
                topics[topicId].topicFeePercentage +
                topics[topicId].prevContributorsFeePercentage <=
                10000,
            "accumulative fees exceeded 100%"
        );
        if (info.choiceCreationFee > 0) {
            IERC20Upgradeable(info.token).safeTransferFrom(
                msg.sender,
                info.funds,
                info.choiceCreationFee
            );
        }

        topicChoices[topicId].push(choice);
    }

    function getArenaFee(uint256 amount) internal view returns (uint256) {
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

    function vote(
        uint256 topicId,
        uint256 choiceId,
        uint256 amount
    ) public {
        require(
            amount >= info.minContributionAmount,
            "contribution amount too low"
        );
        IERC20Upgradeable(info.token).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        Topic memory topic = topics[topicId];
        Choice memory choice = topicChoices[topicId][choiceId];
        Position storage choicePosition = choicePositionSummery[topicId][
            choiceId
        ];

        claimableBalance[info.funds] += getArenaFee(amount);
        claimableBalance[topic.funds] += getTopicFee(topic, amount);
        claimableBalance[choice.funds] += getChoiceFee(choice, amount);

        uint256 netVoteAmount = amount -
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
                i < choiceVoters[topicId][choiceId].length;
                i++
            ) {
                Position storage thePosition = positions[
                    choiceVoters[topicId][choiceId][i]
                ][topicId][choiceId];
                uint256 fee = (prevFee * thePosition.getShares(topic)) /
                    totalShares;
                thePosition.updatePosition(topic, fee);
                choicePosition.updatePosition(topic, fee);
            }
        }

        if (positions[msg.sender][topicId][choiceId].isEmpty()) {
            choiceVoters[topicId][choiceId].push(msg.sender);
        }

        positions[msg.sender][topicId][choiceId].updatePosition(
            topic,
            netVoteAmount
        );

        choicePositionSummery[topicId][choiceId].updatePosition(
            topic,
            netVoteAmount
        );
    }

    function getVoterPositionOnChoice(
        uint256 topicId,
        uint256 choiceId,
        address voter
    ) public view returns (uint256 tokens, uint256 shares) {
        Position storage _position = positions[voter][topicId][choiceId];
        return (_position.tokens, _position.getShares(topics[topicId]));
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
        return claimableBalance[account];
    }
}
