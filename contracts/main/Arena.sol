// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "./ArenaUtils.sol";

contract Arena is Initializable, AccessControlUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    mapping(address => uint256) public claimableBalance; // amount of "info._token" that an address can withdraw from the arena

    ArenaInfo public info;
    TopicData internal topicData;
    PositionData internal positionsData;
    ChoiceData internal choiceData;

    event AddTopic(uint256 topicId, Topic topic);
    event RemoveTopic(uint256 topicId);
    event AddChoice(uint256 choiceId, uint256 topicId, Choice choice);
    event RemoveChoice(uint256 choiceId, uint256 topicId);
    event Withdaw(
        address user,
        uint256 topicId,
        uint256 choiceId,
        uint256 positionIndex,
        uint256 amount
    );
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

    // ============== core state views =============== //
    function getNextTopicId() public view returns (uint256) {
        return topicData.topics.length;
    }

    function getNextChoiceIdInTopic(uint256 topicId)
        public
        view
        returns (uint256)
    {
        return choiceData.topicChoices[topicId].length;
    }

    function topics(uint256 topicId) public view returns (Topic memory) {
        return topicData.topics[topicId];
    }

    function isTopicDeleted(uint256 topicId) public view returns (bool) {
        return topicData.isTopicDeleted[topicId];
    }

    function topicChoices(uint256 topicId, uint256 choiceId)
        public
        view
        returns (Choice memory)
    {
        return choiceData.topicChoices[topicId][choiceId];
    }

    function isChoiceDeleted(uint256 topicId, uint256 choiceId)
        public
        view
        returns (bool)
    {
        return choiceData.isChoiceDeleted[topicId][choiceId];
    }

    // ============== core state functions =============== //
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
        topicData.topics.push(topic);
    }

    function removeTopic(uint256 topicId)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        topicData.isTopicDeleted[topicId] = true;
        emit RemoveTopic(topicId);
    }

    function addChoice(uint256 topicId, Choice memory choice) public {
        require(
            choice.feePercentage <=
                topicData.topics[topicId].maxChoiceFeePercentage,
            "Arena: HIGH_FEE_PERCENTAGE"
        );

        require(
            choice.feePercentage +
                info.arenaFeePercentage +
                topicData.topics[topicId].topicFeePercentage +
                topicData.topics[topicId].prevContributorsFeePercentage <=
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
        choiceData.topicChoices[topicId].push(choice);
    }

    function removeChoice(uint256 topicId, uint256 choiceId)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        choiceData.isChoiceDeleted[topicId][choiceId] = true;
        emit RemoveChoice(choiceId, topicId);
    }

    function vote(
        uint256 topicId,
        uint256 choiceId,
        uint256 amount
    ) public {
        require(amount >= info.minContributionAmount, "Arena: LOW_AMOUNT");
        require(
            topicData.isTopicDeleted[topicId] == false,
            "Arena: DELETED_TOPIC"
        );
        require(
            choiceData.isChoiceDeleted[topicId][choiceId] == false,
            "Arena: DELETED_CHOICE"
        );
        IERC20Upgradeable(info.token).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        Topic memory topic = topicData.topics[topicId];
        Choice memory choice = choiceData.topicChoices[topicId][choiceId];
        ChoiceVoteData storage voteData = choiceData.choiceVoteData[topicId][
            choiceId
        ];

        uint256 activeCycle = getActiveCycle(topicId);

        uint256 netVoteAmount = amount -
            (FeeUtils.getArenaFee(info, amount) +
                FeeUtils.getTopicFee(topic, amount) +
                FeeUtils.getChoiceFee(choice, amount));

        uint256 fee = FeeUtils.getPrevFee(topic, amount);

        // update claimable balances
        claimableBalance[info.funds] += FeeUtils.getArenaFee(info, amount);
        claimableBalance[topic.funds] += FeeUtils.getTopicFee(topic, amount);
        claimableBalance[choice.funds] += FeeUtils.getChoiceFee(choice, amount);

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
        Topic memory topic = topicData.topics[topicId];
        uint256 activeCycle = getActiveCycle(topicId);
        uint256 cycle = (position.blockNumber - topic.startBlock) /
            topic.cycleDuration;

        Cycle memory cycleData = choiceData
        .choiceVoteData[topicId][choiceId].cycles[cycle];

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
        Topic memory topic = topicData.topics[topicId];

        Position storage position = positionsData.positions[msg.sender][
            topicId
        ][choiceId][positionIndex];
        uint256 activeCycle = getActiveCycle(topicId);
        uint256 cycle = (position.blockNumber - topic.startBlock) /
            topic.cycleDuration;
        Cycle storage cycleData = choiceData
        .choiceVoteData[topicId][choiceId].cycles[cycle];

        ChoiceVoteData storage voteData = choiceData.choiceVoteData[topicId][
            choiceId
        ];

        (uint256 tokens, uint256 shares) = voterPosition(
            topicId,
            choiceId,
            positionIndex,
            msg.sender
        );
        {
            uint256 principalShare = (position.tokens *
                topic.sharePerCyclePercentage) / 10000;
            uint256 totalFees = (tokens - position.tokens);
            uint256 feeShare = (totalFees * topic.sharePerCyclePercentage) /
                10000;
            uint256 paidShares = ((activeCycle - cycle) *
                (principalShare + feeShare)) - shares;

            cycleData.totalFees -= totalFees;
            cycleData.totalShares -= principalShare + feeShare;
            cycleData.totalSharesPaid -= paidShares;
            cycleData.totalSum -= position.tokens;

            voteData.totalShares -= principalShare;
            voteData.totalSum -= tokens;
            position.tokens = 0;
        }
        IERC20Upgradeable(info.token).safeTransfer(msg.sender, tokens);
        emit Withdaw(msg.sender, topicId, choiceId, positionIndex, tokens);
    }

    function choiceSharesAtCycle(
        uint256 topicId,
        uint256 choiceId,
        uint256 cycle
    ) public view returns (uint256 shares) {
        ChoiceVoteData storage voteData = choiceData.choiceVoteData[topicId][
            choiceId
        ];

        Topic memory topic = topicData.topics[topicId];

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
            (block.number - topicData.topics[topicId].startBlock) /
            topicData.topics[topicId].cycleDuration;
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
        tokens = choiceData.choiceVoteData[topicId][choiceId].totalSum;
    }

    function balanceOf(address account) public view returns (uint256) {
        return claimableBalance[account];
    }

    // todo: erc20 and erc10 recovery
}
