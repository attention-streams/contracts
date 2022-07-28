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

describe("Attention Streams Setup", () => {
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
      params._arenaFeePercentage = 10100;
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
    it("should create the second valid topic with id of # 1", async () => {
      const params = getValidTopicParams();
      params._cycleDuration = 10;
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
      params._cycleDuration = 10;
      expect(info).to.deep.include.members(getFlatParamsFromDict(params));
    });
    it("Should fail to create topic with topic fee percentage more than 5% (limited by arena)", async () => {
      const params = getValidTopicParams();
      params._topicFeePercentage = 1000; // 10 %
      const tx = addTopic(arena, params);
      await expect(tx).to.be.revertedWith("Max topic fee exceeded");
    });
    it("Should fail to create topic with max choice fee percentage exceeding max choice fee percentage defined by arena", async () => {
      const params = getValidTopicParams();
      params._maxChoiceFeePercentage = 3100; // 31 %
      const tx = addTopic(arena, params);
      await expect(tx).to.be.revertedWith("Max choice fee exceeded");
    });
    it("should fail to create topic with fundingPercentage more than 100%", async () => {
      const params = getValidTopicParams();
      params._fundingPercentage = 10100;
      const tx = addTopic(arena, params);
      await expect(tx).to.be.revertedWith("funding percentage exceeded 100%");
    });

    async function deployArenaWithNoFeeLimits() {
      const arenaParams = getValidArenaParams();
      arenaParams._maxTopicFeePercentage = 10000; // 100 %
      arenaParams._maxChoiceFeePercentage = 10000; // 100 %
      return await deployArena(arenaParams);
    }

    async function deployTopicWithExceedingFees() {
      const arena = await deployArenaWithNoFeeLimits();
      const topicParams = getValidTopicParams();
      topicParams._topicFeePercentage = 3000; // 30 %
      topicParams._prevContributorsFeePercentage = 6500; // 65 %
      // current arrangement: 10(arena) + 30(topic) + 65(contributor) = 105 %
      return addTopic(arena, topicParams);
    }

    it("should fail to create topic with arenaFee + topicFee + contributorFee > 100%", async () => {
      const tx = deployTopicWithExceedingFees();
      await expect(tx).to.be.revertedWith("accumulative fees exceeded 100%");
    });
  });

  describe("Topic Creation Fee", async () => {
    let arena: Arena;
    let token: ERC20;

    async function deployArenaWithTestVoteTokenAndFee() {
      token = await helpers.getTestVoteToken();
      const params = getValidArenaParams();
      params._topicCreationFee = utils.parseEther("10");
      params._token = token.address;
      arena = await deployArena(params);
    }

    it("should create an arena with with topicCreationFee of 10 tokens", async () => {
      await deployArenaWithTestVoteTokenAndFee();
      const info = await arena.info();
      expect(info._topicCreationFee).to.be.equal(utils.parseEther("10"));
    });

    it("should fail to create topic if contract can't spend funds", async () => {
      const [, dev] = await ethers.getSigners();
      const topicParams = getValidTopicParams();
      const tx = addTopic(arena, topicParams, dev);
      await expect(tx).to.be.revertedWith("ERC20: insufficient allowance");
    });
    it("should fail to create topic if balance is low", async () => {
      const [, dev] = await ethers.getSigners();
      const topicCreationFee: BigNumber = (await arena.info())
        ._topicCreationFee;

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
      const fee = (await arena.info())._topicCreationFee;
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
        (
          await arena.info()
        )._funds
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
      const deltaArenaBalance: BigNumber =
        arenaBalanceAfter.sub(arenaBalanceBefore);

      expect(deltaDevBalance.eq(deltaArenaBalance)).to.be.true;
      const fee = (await arena.info())._topicCreationFee;
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
      withFeeParams._choiceCreationFee = ethers.utils.parseEther("10"); // 10 tokens as fee
      withFeeParams._token = token.address;
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
    it("should fail to create choice if fee percentage is more than allowed by topic", async () => {
      const params = getValidChoiceParams();
      params._feePercentage = 2600;
      const tx = addChoice(arenaNoFee, topic, params);
      await expect(tx).to.be.revertedWith("Fee percentage too high");
    });

    async function ConfigureAndDeployArena() {
      const arenaParams = getValidArenaParams(); // arena fee is 10%
      arenaParams._maxChoiceFeePercentage = 10000;
      arenaParams._maxTopicFeePercentage = 10000;
      return await deployArena(arenaParams);
    }

    async function configureAndAddTopic(_arena: Arena) {
      const topicParams = getValidTopicParams();
      topicParams._maxChoiceFeePercentage = 10000;
      topicParams._topicFeePercentage = 6000;
      const _topic = await addTopic(_arena, topicParams);
      await _topic.wait(1);
      return _topic;
    }

    async function configureAndAddChoice(_arena: Arena) {
      const choiceParams = getValidChoiceParams();
      choiceParams._feePercentage = 4000;
      return addChoice(_arena, BigNumber.from(0), choiceParams);
    }

    it("should fail to create choice if accumulative fee is more than 100%", async () => {
      const _arena = await ConfigureAndDeployArena();
      await configureAndAddTopic(_arena);
      const _choice = configureAndAddChoice(_arena);

      await expect(_choice).to.be.revertedWith(
        "accumulative fees exceeded 100%"
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
          (
            await arenaWithFee.info()
          )._choiceCreationFee
        );
      await approve.wait(1);
      const tx = addChoice(arenaWithFee, topic, getValidChoiceParams(), dev);
      await expect(tx).to.be.revertedWith(
        "ERC20: transfer amount exceeds balance"
      );
    });

    async function fundDevAccountAndApprove() {
      const [owner, dev] = await ethers.getSigners();
      const fee = (await arenaWithFee.info())._choiceCreationFee;
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
        (
          await arenaWithFee.info()
        )._funds
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
      const [deltaDevBalance, deltaChoiceFundsBalance] =
        await addChoiceAndGetDelta();

      expect(deltaDevBalance.eq(deltaChoiceFundsBalance)).to.be.true;
      expect(
        deltaDevBalance.eq((await arenaWithFee.info())._choiceCreationFee)
      );
    });
  });
});
