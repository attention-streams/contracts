// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "./ArenaUtils.sol";

import "hardhat/console.sol";

struct PositionsData {
    mapping(address => mapping(uint256 => mapping(uint256 => Position[]))) positions; // positions of each user in each choice of each topic // address => (topicId => (choiceId => Position[]))
    mapping(address => mapping(uint256 => mapping(uint256 => uint256))) positionsLength; // address => (topicId => (choiceId => positions length))
    mapping(address => mapping(uint256 => mapping(uint256 => uint256))) nextPositionToWithdraw; // address => (topicId => (choiceId => next position to withdraw))
}

contract Arena is Initializable, AccessControlUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // state variables
    ArenaInfo public info;
    Topic[] public topics; // list of topics in arena

    PositionsData internal positionsData;

    mapping(uint256 => Choice[]) public topicChoices; // list of choices of each topic
    mapping(uint256 => mapping(uint256 => ChoiceVoteData))
        public choiceVoteData; // topicId => choiceId => aggregated vote data

    mapping(uint256 => bool) public isTopicDeleted; // indicates if a topic is deleted or not. (if deleted, not voting can happen)
    mapping(uint256 => mapping(uint256 => bool)) public isChoiceDeleted; // topicId => choiceId => isDeleted

    mapping(address => uint256) public claimableBalance; // amount of "info._token" that an address can withdraw from the arena

    event AddTopic(uint256 topicId, Topic topic);
    event RemoveTopic(uint256 topicId);
    event AddChoice(uint256 choiceId, uint256 topicId, Choice choice);
    event RemoveChoice(uint256 choiceId, uint256 topicId);
    event Vote(
        address user,
        uint256 amount,
        uint256 choiceId,
        uint256 topicId,
        uint256 cycle
    );

    function initialize(ArenaInfo memory _info) public initializer {
        require(
            (_info.arenaFeePercentage) <= 100 * 10**2,
            "Arena: MAX_FEE_EXCEEDED"
        );
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
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
            "Arena: FUNDING_FEE_EXCEEDED"
        );

        require(
            topic.topicFeePercentage <= info.maxTopicFeePercentage,
            "Arena: TOPIC_FEE_EXCEEDED"
        );
        require(
            topic.maxChoiceFeePercentage <= info.maxChoiceFeePercentage,
            "Arena: CHOICE_FEE_EXCEEDED"
        );
        require(
            info.arenaFeePercentage +
                topic.topicFeePercentage +
                topic.prevContributorsFeePercentage <=
                10000,
            "Arena: ACCUMULATIVE_FEE_EXCEEDED"
        );

        emit AddTopic(getNextTopicId(), topic);
        topics.push(topic);
    }

    function removeTopic(uint256 topicId)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        isTopicDeleted[topicId] = true;
        emit RemoveTopic(topicId);
    }

    function addChoice(uint256 topicId, Choice memory choice) public {
        require(
            choice.feePercentage <= topics[topicId].maxChoiceFeePercentage,
            "Arena: HIGH_FEE_PERCENTAGE"
        );

        require(
            choice.feePercentage +
                info.arenaFeePercentage +
                topics[topicId].topicFeePercentage +
                topics[topicId].prevContributorsFeePercentage <=
                10000,
            "Arena: ACCUMULATIVE_FEE_EXCEEDED"
        );
        if (info.choiceCreationFee > 0) {
            IERC20Upgradeable(info.token).safeTransferFrom(
                msg.sender,
                info.funds,
                info.choiceCreationFee
            );
        }
        emit AddChoice(getNextChoiceIdInTopic(topicId), topicId, choice);
        topicChoices[topicId].push(choice);
    }

    function removeChoice(uint256 topicId, uint256 choiceId)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        isChoiceDeleted[topicId][choiceId] = true;
        emit RemoveChoice(choiceId, topicId);
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
        require(amount >= info.minContributionAmount, "Arena: LOW_AMOUNT");
        require(isTopicDeleted[topicId] == false, "Arena: DELETED_TOPIC");
        require(
            isChoiceDeleted[topicId][choiceId] == false,
            "Arena: DELETED_CHOICE"
        );
        IERC20Upgradeable(info.token).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        Topic memory topic = topics[topicId];
        Choice memory choice = topicChoices[topicId][choiceId];
        ChoiceVoteData storage voteData = choiceVoteData[topicId][choiceId];

        uint256 activeCycle = getActiveCycle(topicId);

        uint256 netVoteAmount = amount -
            (getArenaFee(amount) +
                getTopicFee(topic, amount) +
                getChoiceFee(choice, amount));

        uint256 fee = getPrevFee(topic, amount);

        // update claimable balances
        claimableBalance[info.funds] += getArenaFee(amount);
        claimableBalance[topic.funds] += getTopicFee(topic, amount);
        claimableBalance[choice.funds] += getChoiceFee(choice, amount);

        if (activeCycle > 0) {
            voteData.totalShares = choiceSharesAtCycle(
                topicId,
                choiceId,
                activeCycle
            );
            voteData.updatedAt = activeCycle;
        }

        if (int256(activeCycle) - 1 >= 0 && voteData.totalShares != 0) {
            netVoteAmount -= fee;
            // update previouse cycles share
            for (int256 it = int256(activeCycle) - 1; it >= 0; it--) {
                uint256 i = uint256(it);
                uint256 cycleShares = (activeCycle - i) *
                    voteData.cycles[i].totalShares -
                    voteData.cycles[i].totalSharesPaid;

                uint256 feeForCycle = (fee * cycleShares) /
                    voteData.totalShares;
                uint256 feeShare = (feeForCycle *
                    topic.sharePerCyclePercentage) / 10000;
                voteData.cycles[i].totalShares += feeShare;
                voteData.cycles[i].totalSharesPaid +=
                    (activeCycle - i) *
                    feeShare;
                voteData.cycles[i].totalFees += feeForCycle;
                voteData.totalSum += feeForCycle;
            }
        }
        // update total sharers of cycle
        voteData.cycles[activeCycle].totalShares +=
            (netVoteAmount * topic.sharePerCyclePercentage) /
            10000;

        // update total raw investmenst in this cycle
        voteData.cycles[activeCycle].totalSum += netVoteAmount;

        // update total investments on this choice
        voteData.totalSum += netVoteAmount;
        positionsData.positions[msg.sender][topicId][choiceId].push(
            Position(netVoteAmount, block.number, 0)
        );

        emit Vote(msg.sender, netVoteAmount, choiceId, topicId, activeCycle);
    }

    function voterPosition(
        uint256 topicId,
        uint256 choiceId,
        uint256 positionIndex,
        address voter
    ) public view returns (uint256 tokens, uint256 shares) {
        Position memory position = positionsData.positions[voter][topicId][
            choiceId
        ][positionIndex];
        Topic memory topic = topics[topicId];
        uint256 activeCycle = getActiveCycle(topicId);
        uint256 cycle = (position.blockNumber - topic.startBlock) /
            topic.cycleDuration;

        Cycle memory cycleData = choiceVoteData[topicId][choiceId].cycles[
            cycle
        ];

        tokens =
            position.tokens +
            ((position.tokens * cycleData.totalFees) / cycleData.totalSum);
        shares =
            (position.tokens *
                (((activeCycle - cycle) * cycleData.totalShares) -
                    cycleData.totalSharesPaid)) /
            cycleData.totalSum;
    }

    function withdrawPosition(
        uint256 topicId,
        uint256 choiceId,
        uint256 positionIndex
    ) public {
        Topic memory topic = topics[topicId];

        Position storage position = positionsData.positions[msg.sender][
            topicId
        ][choiceId][positionIndex];
        uint256 activeCycle = getActiveCycle(topicId);
        uint256 cycle = (position.blockNumber - topic.startBlock) /
            topic.cycleDuration;
        Cycle storage cycleData = choiceVoteData[topicId][choiceId].cycles[
            cycle
        ];

        ChoiceVoteData storage voteData = choiceVoteData[topicId][choiceId];

        (uint256 tokens, uint256 shares) = voterPosition(
            topicId,
            choiceId,
            positionIndex,
            msg.sender
        );
        uint256 principalShare = (position.tokens *
            topic.sharePerCyclePercentage) / 10000;
        uint256 totalFees = (tokens - position.tokens);
        uint256 feeShare = (totalFees * topic.sharePerCyclePercentage) / 10000;
        uint256 paidShares = ((activeCycle - cycle) *
            (principalShare + feeShare)) - shares;

        cycleData.totalFees -= totalFees;
        cycleData.totalShares -= principalShare + feeShare;
        cycleData.totalSharesPaid -= paidShares;
        cycleData.totalSum -= position.tokens;

        voteData.totalShares -= principalShare;
        voteData.totalSum -= tokens;
        position.tokens = 0;
        IERC20Upgradeable(info.token).safeTransfer(msg.sender, tokens);
    }

    function choiceSharesAtCycle(
        uint256 topicId,
        uint256 choiceId,
        uint256 cycle
    ) public view returns (uint256 shares) {
        ChoiceVoteData storage voteData = choiceVoteData[topicId][choiceId];

        Topic memory topic = topics[topicId];

        if (cycle > 0) {
            uint256 lastUpdateCycle;
            if (voteData.updatedAt == 0) {
                lastUpdateCycle = cycle - 1;
            } else {
                lastUpdateCycle = voteData.updatedAt;
            }
            shares =
                voteData.totalShares +
                (cycle - lastUpdateCycle) *
                ((voteData.totalSum * topic.sharePerCyclePercentage) / 10000);
        }
    }

    function aggregatedVoterPosition(
        uint256 topicId,
        uint256 choiceId,
        address voter
    ) public view returns (uint256 tokens, uint256 shares) {
        for (
            uint32 i = 0;
            i < positionsData.positions[voter][topicId][choiceId].length;
            i++
        ) {
            (uint256 _tokens, uint256 _shares) = voterPosition(
                topicId,
                choiceId,
                i,
                voter
            );
            tokens += _tokens;
            shares += _shares;
        }
    }

    function getActiveCycle(uint256 topicId) public view returns (uint256) {
        return
            (block.number - topics[topicId].startBlock) /
            topics[topicId].cycleDuration;
    }

    function choiceSummery(uint256 topicId, uint256 choiceId)
        public
        view
        returns (uint256 tokens, uint256 shares)
    {
        shares = choiceSharesAtCycle(
            topicId,
            choiceId,
            getActiveCycle(topicId)
        );
        tokens = choiceVoteData[topicId][choiceId].totalSum;
    }

    function balanceOf(address account) public view returns (uint256) {
        return claimableBalance[account];
    }

    // todo: erc20 and erc10 recovery
}
