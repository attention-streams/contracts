import { expect } from "chai";
import { BigNumber, utils } from "ethers";
import helpers from "../scripts/helpers";

import { addChoice, addTopic, deployArena } from "../scripts/deploy";
import { Arena, ERC20 } from "../typechain";
import {
  getFlatParamsFromDict,
  getValidArenaParams,
  getValidChoiceParams,
  getValidTopicParams,
} from "./test.creations.data";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

describe("Attention Streams Setup", () => {
  let admin: SignerWithAddress;
  let user: SignerWithAddress;
  before(async () => {
    [admin, user] = await ethers.getSigners();
  });
  describe("Arena creation", () => {
    let arena: Arena;
    it("should deploy arena with valid configuration", async () => {
      arena = await deployArena(getValidArenaParams());
      expect(arena.address).to.not.be.null;
    });
    it("should properly retrieve the deployed arena info", async () => {
      const arenaInfo = await arena.functions.info();
      expect(arenaInfo).deep.include.members(
        getFlatParamsFromDict(getValidArenaParams())
      );
      expect(arena.address).not.null;
    });

    it("should fail to create arena with fee percentage more than 100%", async () => {
      const params = getValidArenaParams();
      params.arenaFeePercentage = 10100;
      await expect(deployArena(params)).to.be.reverted;
    });
  });
  describe("Topic Creation", () => {
    let arena: Arena;
    before(async () => {
      // create arena
      arena = await deployArena(getValidArenaParams());
    });
    it("should create the first valid topic with id of # 0", async () => {
      const tx = await addTopic(arena, getValidTopicParams());
      await tx.wait(1);
      const nextId = await arena.getNextTopicId();
      expect(nextId).to.be.equal(1);
    });
    it("should fail to remove topic if not admin", async () => {
      const tx = arena.connect(user).removeTopic(0);
      await expect(tx).to.be.reverted;
    });
    it("should remove topic 0 if admin", async () => {
      await arena.removeTopic(0);
      let isTopicDeleted = await arena.isTopicDeleted(0);
      expect(isTopicDeleted).to.be.true;
    });
    it("should create the second valid topic with id of # 1", async () => {
      const params = getValidTopicParams();
      params.cycleDuration = 10;
      const tx = await addTopic(arena, params);
      await tx.wait(1);
      const nextId = await arena.getNextTopicId();
      expect(nextId).to.be.equal(2);
    });
    it("should properly retrieve topic # 0 info", async () => {
      const info = await arena.topics(0);
      const params = getValidTopicParams();
      expect(info).to.deep.include.members(getFlatParamsFromDict(params));
    });
    it("should properly retrieve topic # 1 info", async () => {
      const info = await arena.topics(1);
      const params = getValidTopicParams();
      params.cycleDuration = 10;
      expect(info).to.deep.include.members(getFlatParamsFromDict(params));
    });
    it("Should fail to create topic with topic fee percentage more than 5% (limited by arena)", async () => {
      const params = getValidTopicParams();
      params.topicFeePercentage = 1000; // 10 %
      const tx = addTopic(arena, params);
      await expect(tx).to.be.revertedWith("Arena: TOPIC_FEE_EXCEEDED");
    });
    it("Should fail to create topic with max choice fee percentage exceeding max choice fee percentage defined by arena", async () => {
      const params = getValidTopicParams();
      params.maxChoiceFeePercentage = 3100; // 31 %
      const tx = addTopic(arena, params);
      await expect(tx).to.be.revertedWith("Arena: CHOICE_FEE_EXCEEDED");
    });
    it("should fail to create topic with fundingPercentage more than 100%", async () => {
      const params = getValidTopicParams();
      params.fundingPercentage = 10100;
      const tx = addTopic(arena, params);
      await expect(tx).to.be.revertedWith("Arena: FUNDING_FEE_EXCEEDED");
    });

    async function deployArenaWithNoFeeLimits() {
      const arenaParams = getValidArenaParams();
      arenaParams.maxTopicFeePercentage = 10000; // 100 %
      arenaParams.maxChoiceFeePercentage = 10000; // 100 %
      return await deployArena(arenaParams);
    }

    async function deployTopicWithExceedingFees() {
      const arena = await deployArenaWithNoFeeLimits();
      const topicParams = getValidTopicParams();
      topicParams.topicFeePercentage = 3000; // 30 %
      topicParams.prevContributorsFeePercentage = 6500; // 65 %
      // current arrangement: 10(arena) + 30(topic) + 65(contributor) = 105 %
      return addTopic(arena, topicParams);
    }

    it("should fail to create topic with arenaFee + topicFee + contributorFee > 100%", async () => {
      const tx = deployTopicWithExceedingFees();
      await expect(tx).to.be.revertedWith("Arena: ACCUMULATIVE_FEE_EXCEEDED");
    });
  });

  describe("Topic Creation Fee", async () => {
    let arena: Arena;
    let token: ERC20;

    async function deployArenaWithTestVoteTokenAndFee() {
      token = await helpers.getTestVoteToken();
      const params = getValidArenaParams();
      params.topicCreationFee = utils.parseEther("10");
      params.token = token.address;
      arena = await deployArena(params);
    }

    it("should create an arena with with topicCreationFee of 10 tokens", async () => {
      await deployArenaWithTestVoteTokenAndFee();
      const info = await arena.info();
      expect(info.topicCreationFee).to.be.equal(utils.parseEther("10"));
    });

    it("should fail to create topic if contract can't spend funds", async () => {
      const [, dev] = await ethers.getSigners();
      const topicParams = getValidTopicParams();
      const tx = addTopic(arena, topicParams, dev);
      await expect(tx).to.be.revertedWith("ERC20: insufficient allowance");
    });
    it("should fail to create topic if balance is low", async () => {
      const [, dev] = await ethers.getSigners();
      const topicCreationFee: BigNumber = (await arena.info()).topicCreationFee;

      // approve the contract to spend funds
      const approveTx = await token
        .connect(dev)
        .approve(arena.address, topicCreationFee);
      await approveTx.wait(1);

      const tx = addTopic(arena, getValidTopicParams(), dev);

      await expect(tx).to.be.revertedWith(
        "ERC20: transfer amount exceeds balance"
      );
    });

    async function fundDevAccountAndApprove() {
      const [owner, dev] = await ethers.getSigners();
      const fee = (await arena.info()).topicCreationFee;
      // transfer some funds from owner to dev
      const transferTx = await token.connect(owner).transfer(dev.address, fee);
      await transferTx.wait(1);

      // approve the contract to spend funds
      const approveTx = await token.connect(dev).approve(arena.address, fee);
      await approveTx.wait(1);
    }

    async function snapshot() {
      const [, dev] = await ethers.getSigners();
      const devBalance: BigNumber = await token.balanceOf(dev.address);
      const arenaFundsBalance: BigNumber = await token.balanceOf(
        (await arena.info()).funds
      );
      return [devBalance, arenaFundsBalance];
    }

    async function configureAndAddTopic() {
      const [, dev] = await ethers.getSigners();
      const topicParams = getValidTopicParams();
      const addTopicTx = await addTopic(arena, topicParams, dev);
      await addTopicTx.wait(1);
    }

    it("should subtract topicCreationFee amount from creator and add it to arena funds", async () => {
      await fundDevAccountAndApprove();
      const [devBalanceBefore, arenaBalanceBefore] = await snapshot();
      await configureAndAddTopic();
      const [devBalanceAfter, arenaBalanceAfter] = await snapshot();
      const deltaDevBalance: BigNumber = devBalanceBefore.sub(devBalanceAfter);
      const deltaArenaBalance: BigNumber = arenaBalanceAfter.sub(
        arenaBalanceBefore
      );

      expect(deltaDevBalance.eq(deltaArenaBalance)).to.be.true;
      const fee = (await arena.info()).topicCreationFee;
      expect(deltaArenaBalance).equal(fee);
    });
  });

  describe("Choice Creation", async () => {
    let arenaNoFee: Arena;
    let arenaWithFee: Arena;
    let token: ERC20;
    let topic: BigNumber;

    async function deployNoFeeArena() {
      arenaNoFee = await deployArena(getValidArenaParams());
      const createTopic1 = await addTopic(arenaNoFee, getValidTopicParams());
      await createTopic1.wait(1);
    }

    async function deployTestVoteToken() {
      const withFeeParams = getValidArenaParams();
      token = await helpers.getTestVoteToken();
      return withFeeParams;
    }

    async function deployWithFeeArena() {
      const withFeeParams = await deployTestVoteToken();
      withFeeParams.choiceCreationFee = ethers.utils.parseEther("10"); // 10 tokens as fee
      withFeeParams.token = token.address;
      arenaWithFee = await deployArena(withFeeParams);
      const createTopic2 = await addTopic(arenaWithFee, getValidTopicParams());
      await createTopic2.wait(1);
    }

    before(async () => {
      await deployNoFeeArena();
      await deployTestVoteToken();
      await deployWithFeeArena();

      topic = (await arenaNoFee.getNextTopicId()).sub(1);
    });
    it("should create valid choice with id # 0", async () => {
      const addChoiceTx = await addChoice(
        arenaNoFee,
        topic,
        getValidChoiceParams()
      );
      await addChoiceTx.wait(1);
      const nextChoiceId = await arenaNoFee.getNextChoiceIdInTopic(topic);
      expect(nextChoiceId).to.equal(BigNumber.from(1));
    });

    it("should retrieve the first choices info", async () => {
      const choiceInfo = await arenaNoFee.topicChoices(topic, 0);
      const params = getFlatParamsFromDict(getValidChoiceParams());
      expect(choiceInfo).to.deep.include.members(params);
    });
    it("should fail to remove choice if not admin ", async () => {
      const tx = arenaNoFee.connect(user).removeChoice(topic, 0);
      await expect(tx).to.be.reverted;
    });
    it("should remove choice if admin", async () => {
      await arenaNoFee.removeChoice(topic, 0);
      const isDeleted = await arenaNoFee.isChoiceDeleted(topic, 0);
      expect(isDeleted).to.be.true;
    });
    it("should fail to create choice if fee percentage is more than allowed by topic", async () => {
      const params = getValidChoiceParams();
      params.feePercentage = 2600;
      const tx = addChoice(arenaNoFee, topic, params);
      await expect(tx).to.be.revertedWith("Arena: HIGH_FEE_PERCENTAGE");
    });

    async function ConfigureAndDeployArena() {
      const arenaParams = getValidArenaParams(); // arena fee is 10%
      arenaParams.maxChoiceFeePercentage = 10000;
      arenaParams.maxTopicFeePercentage = 10000;
      return await deployArena(arenaParams);
    }

    async function configureAndAddTopic(arena: Arena) {
      const topicParams = getValidTopicParams();
      topicParams.maxChoiceFeePercentage = 10000;
      topicParams.topicFeePercentage = 6000;
      const topic = await addTopic(arena, topicParams);
      await topic.wait(1);
      return topic;
    }

    async function configureAndAddChoice(arena: Arena) {
      const choiceParams = getValidChoiceParams();
      choiceParams.feePercentage = 4000;
      return addChoice(arena, BigNumber.from(0), choiceParams);
    }

    it("should fail to create choice if accumulative fee is more than 100%", async () => {
      const arena = await ConfigureAndDeployArena();
      await configureAndAddTopic(arena);
      const choice = configureAndAddChoice(arena);

      await expect(choice).to.be.revertedWith(
        "Arena: ACCUMULATIVE_FEE_EXCEEDED"
      );
    });
    it("should fail to create choice if contract can't spend funds", async () => {
      const tx = addChoice(arenaWithFee, topic, getValidChoiceParams());
      await expect(tx).to.be.revertedWith("ERC20: insufficient allowance");
    });
    it("should fail to create choice if balance is too low", async () => {
      const [, dev] = await ethers.getSigners();
      const approve = await token
        .connect(dev)
        .approve(
          arenaWithFee.address,
          (await arenaWithFee.info()).choiceCreationFee
        );
      await approve.wait(1);
      const tx = addChoice(arenaWithFee, topic, getValidChoiceParams(), dev);
      await expect(tx).to.be.revertedWith(
        "ERC20: transfer amount exceeds balance"
      );
    });

    async function fundDevAccountAndApprove() {
      const [owner, dev] = await ethers.getSigners();
      const fee = (await arenaWithFee.info()).choiceCreationFee;
      const transfer = await token.connect(owner).transfer(dev.address, fee);
      await transfer.wait(1);
      const approve = await token
        .connect(dev)
        .approve(arenaWithFee.address, fee);
      await approve.wait(1);
    }

    async function snapshot() {
      const [, dev] = await ethers.getSigners();
      const devBalanceBefore = await token.balanceOf(dev.address);
      const choiceFundsBalanceBefore = await token.balanceOf(
        (await arenaWithFee.info()).funds
      );
      return [devBalanceBefore, choiceFundsBalanceBefore];
    }

    async function _addChoice() {
      const [, dev] = await ethers.getSigners();
      const tx = await addChoice(
        arenaWithFee,
        topic,
        getValidChoiceParams(),
        dev
      );
      await tx.wait(1);
    }

    async function addChoiceAndGetDelta() {
      await fundDevAccountAndApprove();
      const [devBalanceBefore, arenaFundsBalanceBefore] = await snapshot();
      await _addChoice();
      const [devBalanceAfter, arenaFundsBalanceAfter] = await snapshot();

      return [
        devBalanceBefore.sub(devBalanceAfter),
        arenaFundsBalanceAfter.sub(arenaFundsBalanceBefore),
      ];
    }

    it("should create choice and subtract choiceCreationFee amount", async () => {
      const [
        deltaDevBalance,
        deltaChoiceFundsBalance,
      ] = await addChoiceAndGetDelta();

      expect(deltaDevBalance.eq(deltaChoiceFundsBalance)).to.be.true;
      expect(deltaDevBalance.eq((await arenaWithFee.info()).choiceCreationFee));
    });
  });
});
