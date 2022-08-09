// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "./ArenaUtils.sol";

import "hardhat/console.sol";

contract Arena is Initializable, AccessControlUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using TopicUtils for Topic;

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
    function nextTopicId() public view returns (uint256) {
        return topicData.topics.length;
    }

    function nextChoiceId(uint256 topicId) public view returns (uint256) {
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

    function positionsLength(
        address user,
        uint256 topicId,
        uint256 choiceId
    ) public view returns (uint256) {
        return positionsData.positionsLength[user][topicId][choiceId];
    }

    function nextClaimIndex(
        address user,
        uint256 topicId,
        uint256 choiceId
    ) public view returns (uint256) {
        return positionsData.nextClaimIndex[user][topicId][choiceId];
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

        emit AddTopic(nextTopicId(), topic);
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
        emit AddChoice(nextChoiceId(topicId), topicId, choice);
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
        // todo: check for finish
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

        // deposit arena, topic, and choice fees
        claimableBalance[info.funds] += FeeUtils.getArenaFee(info, amount);
        claimableBalance[topic.funds] += FeeUtils.getTopicFee(topic, amount);
        claimableBalance[choice.funds] += FeeUtils.getChoiceFee(choice, amount);

        uint256 netVoteAmount = amount -
            (FeeUtils.getArenaFee(info, amount) +
                FeeUtils.getTopicFee(topic, amount) +
                FeeUtils.getChoiceFee(choice, amount));

        uint256 activeCycle = getActiveCycle(topicId);

        uint256 fee;
        if (activeCycle > voteData.firstCycle && voteData.totalSum > 0) {
            fee = FeeUtils.getPrevFee(topic, amount); // fees paid to previouse investors
        }
        netVoteAmount -= fee;

        if (voteData.totalSum == 0) {
            voteData.firstCycle = activeCycle;
        }
        // update total raw investmenst in this cycle
        voteData.cycles[activeCycle].generatedFees += fee;
        voteData.cycles[activeCycle].totalSum += netVoteAmount;
        voteData.totalSum += netVoteAmount + fee; // todo: check

        // record the voters vote
        positionsData.positions[msg.sender][topicId][choiceId].push(
            Position(netVoteAmount, block.number, 0)
        );

        emit Vote(msg.sender, netVoteAmount, choiceId, topicId, activeCycle);
    }

    function calculateFees(
        uint256 topicId,
        uint256 choiceId,
        uint256 targetCycle
    )
        public
        view
        returns (
            uint256 earnedFees,
            uint256 shares,
            uint256 totalSum,
            uint256 totalShares
        )
    {
        ChoiceVoteData storage voteData = choiceData.choiceVoteData[topicId][
            choiceId
        ];

        uint256 activeCycle = getActiveCycle(topicId);
        uint256 firstCycle = voteData.firstCycle;
        uint256 deductibleShares;

        FeeData memory feeData = FeeData(
            topics(topicId),
            voteData.cycles[firstCycle],
            new uint256[](activeCycle + 1),
            new uint256[](activeCycle + 1),
            new uint256[](activeCycle + 1),
            new uint256[](activeCycle + 1),
            new uint256[](activeCycle + 1),
            new uint256[](activeCycle + 1)
        );

        totalSum = feeData.cycle.totalSum;
        feeData.cycleShares[firstCycle] = feeData.topic.getShare(
            feeData.cycle.totalSum
        );

        for (uint256 i = firstCycle + 1; i <= activeCycle; i++) {
            // update total shares
            totalShares += feeData.topic.getShare(totalSum);

            // pointer to current cycles data
            feeData.cycle = voteData.cycles[i];

            uint256 cycleTotalSum = feeData.cycle.totalSum -
                feeData.deductibleSum[i];

            totalSum += cycleTotalSum;

            if (totalSum == 0) continue;

            // update cycle shares
            feeData.cycleShares[i] = feeData.topic.getShare(cycleTotalSum);

            for (int256 it = int256(i) - 1; it >= 0; it--) {
                uint256 j = uint256(it);
                uint256 share = (i - j) *
                    feeData.cycleShares[j] -
                    feeData.cycleSharesPaid[j] +
                    feeData.deductiblShares[j];
                uint256 fee = (feeData.cycle.generatedFees * share) /
                    totalShares;

                uint256 feeShare = feeData.topic.getShare(fee);

                feeData.cycleShares[j] += feeShare;
                feeData.cycleSharesPaid[j] += (i - j) * feeShare;
                feeData.cycleFeesEarned[j] += fee;
                totalSum += fee;
            }

            for (uint256 w = 0; w < voteData.withdrawals[i].length; w++) {
                Withdraw memory withdraw = voteData.withdrawals[i][w];
                feeData.deductibleSum[withdraw.cycle] += withdraw.tokens;
                feeData.deductibleFees[withdraw.cycle] += withdraw.fees;

                feeData.cycleShares[withdraw.cycle] -= feeData.topic.getShare(
                    withdraw.tokens + withdraw.fees
                );
                feeData.cycleSharesPaid[withdraw.cycle] -= withdraw.paidShares;

                deductibleShares += withdraw.shares;
                totalSum -= withdraw.tokens + withdraw.fees;
                totalShares -= withdraw.shares;
            }
        }

        earnedFees =
            feeData.cycleFeesEarned[targetCycle] -
            feeData.deductibleFees[targetCycle];
        shares =
            (activeCycle - targetCycle) *
            feeData.cycleShares[targetCycle] -
            feeData.cycleSharesPaid[targetCycle];
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

        uint256 cycle = (position.blockNumber - topic.startBlock) /
            topic.cycleDuration;
        Cycle memory cycleData = choiceData
        .choiceVoteData[topicId][choiceId].cycles[cycle];
        (uint256 earnedFees, uint256 cycleShares, , ) = calculateFees(
            topicId,
            choiceId,
            cycle
        );
        uint256 cycleTotalSum = cycleData.totalSum - cycleData.deductibleSum;
        tokens =
            position.tokens +
            ((position.tokens * earnedFees) / cycleTotalSum);
        shares = (position.tokens * cycleShares) / cycleTotalSum;
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
            uint256 principalShare = topic.getShare(position.tokens);
            uint256 totalFees = (tokens - position.tokens);
            uint256 feeShare = topic.getShare(totalFees);
            uint256 paidShares = ((activeCycle - cycle) *
                (principalShare + feeShare)) - shares;

            voteData.withdrawals[activeCycle].push(
                Withdraw(cycle, position.tokens, totalFees, shares, paidShares)
            );

            cycleData.deductibleSum += position.tokens;
            cycleData.paidFees += totalFees;
            voteData.totalSum -= tokens;
            position.tokens = 0;
        }
        IERC20Upgradeable(info.token).safeTransfer(msg.sender, tokens);
        positionsData.nextClaimIndex[msg.sender][topicId][choiceId]++;
        emit Withdaw(msg.sender, topicId, choiceId, positionIndex, tokens);
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
        (, , tokens, shares) = calculateFees(topicId, choiceId, 0);
    }

    function balanceOf(address account) public view returns (uint256) {
        return claimableBalance[account];
    }

    // todo: erc20 and erc10 recovery
}
