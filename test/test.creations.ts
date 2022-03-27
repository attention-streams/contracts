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
} from "./mock.data";
import { ethers } from "hardhat";

describe("Attention Stream Setup", () => {
  describe("Arena creation", () => {
    let arena: Arena;
    it("Should deploy arena", async () => {
      arena = await deployArena(getValidArenaParams());
      expect(arena.address).to.not.be.null;
    });
    it("Should properly retrieve arena info", async () => {
      const arena_info = await arena.functions.info();
      expect(arena_info).deep.include.members(
        getFlatParamsFromDict(getValidArenaParams())
      );
      expect(arena.address).not.null;
    });

    it("Should fail to create arena with percentage fee more than 100%", async () => {
      const params = getValidArenaParams();
      params.arenaFeePercentage = 10100;
      await expect(deployArena(params)).to.be.reverted;
    });
  });
  describe("Topic Creation", () => {
    describe.skip("skipping", () => {});

    let arena: Arena;
    before(async () => {
      // create arena
      arena = await deployArena(getValidArenaParams());
    });
    it("Should create the first valid topic", async () => {
      const tx = await addTopic(arena, getValidTopicParams());
      await tx.wait(1);
      const nextId = await arena._nextTopicId();
      expect(nextId).to.be.equal(1);
    });
    it("Should create the second valid topic", async () => {
      const params = getValidTopicParams();
      params.cycleDuration = 10;
      const tx = await addTopic(arena, params);
      await tx.wait(1);
      const nextId = await arena._nextTopicId();
      expect(nextId).to.be.equal(2);
    });
    it("Should properly return topic 1 info", async () => {
      const info = await arena.getTopicInfoById(1);
      const params = getValidTopicParams();
      expect(info).to.deep.include.members(getFlatParamsFromDict(params));
    });
    it("Should properly return topic 2 info", async () => {
      const info = await arena.getTopicInfoById(2);
      const params = getValidTopicParams();
      params.cycleDuration = 10;
      expect(info).to.deep.include.members(getFlatParamsFromDict(params));
    });
    it("Should fail to create topic with topic fee more than 5% (limited by arena)", async () => {
      const params = getValidTopicParams();
      params.topicFeePercentage = 1000; // 10 %
      const tx = addTopic(arena, params);
      await expect(tx).to.be.revertedWith("Max topic fee exceeded");
    });
    it("Should fail to create topic with choice fee exceeding max choice fee defined by arena", async () => {
      const params = getValidTopicParams();
      params.maxChoiceFeePercentage = 3100; // 31 %
      const tx = addTopic(arena, params);
      await expect(tx).to.be.revertedWith("Max choice fee exceeded");
    });
    it("Should fail to create topic with fundingPercentage more than 100%", async () => {
      const params = getValidTopicParams();
      params.fundingPercentage = 10100;
      const tx = addTopic(arena, params);
      await expect(tx).to.be.revertedWith("funding percentage exceeded 100%");
    });

    async function deployArenaWithNoFeeLimits() {
      let arenaParams = getValidArenaParams();
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

    it("Should fail to crate topic with arenaFee + topicFee + contributorFee > 100%", async () => {
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
      params.topicCreationFee = utils.parseEther("10");
      params.token = token.address;
      arena = await deployArena(params);
    }

    it("Should create arena fee topic creation fee of 10 tokens", async () => {
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
      const topicCreationFee: BigNumber = await arena._topicCreationFee();

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
      let [owner, dev] = await ethers.getSigners();
      let fee = await arena._topicCreationFee();
      // transfer some funds from owner to dev
      const transferTx = await token.connect(owner).transfer(dev.address, fee);
      await transferTx.wait(1);

      // approve the contract to spend funds
      const approveTx = await token.connect(dev).approve(arena.address, fee);
      await approveTx.wait(1);
    }

    async function snapshot() {
      let [, dev] = await ethers.getSigners();
      const devBalance: BigNumber = await token.balanceOf(dev.address);
      const arenaFundsBalance: BigNumber = await token.balanceOf(arena.address);
      return [devBalance, arenaFundsBalance];
    }

    async function configureAndAddTopic() {
      let [, dev] = await ethers.getSigners();
      const topicParams = getValidTopicParams();
      const addTopicTx = await addTopic(arena, topicParams, dev);
      await addTopicTx.wait(1);
    }

    it("should subtract fee amount from creator and add it to arena funds", async () => {
      await fundDevAccountAndApprove();

      const [devBalanceBefore, arenaBalanceBefore] = await snapshot();

      await configureAndAddTopic();

      const [devBalanceAfter, arenaBalanceAfter] = await snapshot();

      const deltaDevBalance: BigNumber = devBalanceBefore.sub(devBalanceAfter);
      const deltaArenaBalance: BigNumber =
        arenaBalanceAfter.sub(arenaBalanceBefore);

      expect(deltaDevBalance.eq(deltaArenaBalance)).to.be.true;
      expect(deltaArenaBalance.eq(await arena._topicCreationFee())).to.be.true;
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
      let withFeeParams = getValidArenaParams();
      token = await helpers.getTestVoteToken();
      return withFeeParams;
    }

    async function deployWithFeeArena() {
      let withFeeParams = await deployTestVoteToken();
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

      topic = await arenaNoFee._nextTopicId();
    });
    it("should create valid choice", async () => {
      const addChoiceTx = await addChoice(
        arenaNoFee,
        topic,
        getValidChoiceParams()
      );
      await addChoiceTx.wait(1);

      const nextChoiceId = await arenaNoFee._topicChoiceNextId(topic);
      expect(nextChoiceId).to.equal(BigNumber.from(1));
    });
    it("should retrieve the first choices info", async () => {
      let choiceInfo = await arenaNoFee.choiceInfo(topic, 0);
      let params = getFlatParamsFromDict(getValidChoiceParams());
      expect(choiceInfo).to.deep.include.members(params);
    });
    it("should fail to create choice if fee is more than allowed by topic", async () => {
      let params = getValidChoiceParams();
      params.feePercentage = 2600;
      let tx = addChoice(arenaNoFee, topic, params);
      await expect(tx).to.be.revertedWith("Fee percentage too high");
    });

    async function ConfigureAndDeployArena() {
      let arenaParams = getValidArenaParams(); // arena fee is 10%
      arenaParams.maxChoiceFeePercentage = 10000;
      arenaParams.maxTopicFeePercentage = 10000;
      return await deployArena(arenaParams);
    }

    async function configureAndAddTopic(_arena: Arena) {
      let topicParams = getValidTopicParams();
      topicParams.maxChoiceFeePercentage = 10000;
      topicParams.topicFeePercentage = 6000;
      let _topic = await addTopic(_arena, topicParams);
      await _topic.wait(1);
      return _topic;
    }

    async function configureAndAddChoice(_arena: Arena) {
      let choiceParams = getValidChoiceParams();
      choiceParams.feePercentage = 4000;
      return addChoice(_arena, BigNumber.from(1), choiceParams);
    }

    it("should fail to create choice if accumulative fee is more than 100%", async () => {
      let _arena = await ConfigureAndDeployArena();
      await configureAndAddTopic(_arena);
      let _choice = configureAndAddChoice(_arena);

      await expect(_choice).to.be.revertedWith(
        "accumulative fees exceeded 100%"
      );
    });
    it("should fail to create choice if contract can't spend funds", async () => {
      let tx = addChoice(arenaWithFee, topic, getValidChoiceParams());
      await expect(tx).to.be.revertedWith("ERC20: insufficient allowance");
    });
    it("should fail to create choice if balance is too low", async () => {
      let [, dev] = await ethers.getSigners();
      await token
        .connect(dev)
        .approve(arenaWithFee.address, await arenaWithFee._choiceCreationFee());
      let tx = addChoice(arenaWithFee, topic, getValidChoiceParams(), dev);
      await expect(tx).to.be.revertedWith(
        "ERC20: transfer amount exceeds balance"
      );
    });

    async function fundDevAccountAndApprove() {
      let [owner, dev] = await ethers.getSigners();
      let fee = await arenaWithFee._choiceCreationFee();
      let transfer = await token.connect(owner).transfer(dev.address, fee);
      await transfer.wait(1);
      let approve = await token.connect(dev).approve(arenaWithFee.address, fee);
      await approve.wait(1);
    }

    async function snapshot() {
      let [, dev] = await ethers.getSigners();
      let devBalanceBefore = await token.balanceOf(dev.address);
      let choiceFundsBalanceBefore = await token.balanceOf(
        getValidChoiceParams().funds
      );
      return [devBalanceBefore, choiceFundsBalanceBefore];
    }

    async function _addChoice() {
      let [, dev] = await ethers.getSigners();
      let tx = await addChoice(
        arenaWithFee,
        topic,
        getValidChoiceParams(),
        dev
      );
      await tx.wait(1);
    }

    async function addChoiceAndGetDelta() {
      await fundDevAccountAndApprove();
      let [devBalanceBefore, choiceFundsBalanceBefore] = await snapshot();
      await _addChoice();
      let [devBalanceAfter, choiceFundsBalanceAfter] = await snapshot();

      return [
        devBalanceBefore.sub(devBalanceAfter),
        choiceFundsBalanceAfter.sub(choiceFundsBalanceBefore),
      ];
    }

    it("should create choice and subtract fee", async () => {
      let [deltaDevBalance, deltaChoiceFundsBalance] =
        await addChoiceAndGetDelta();

      expect(deltaDevBalance.eq(deltaChoiceFundsBalance)).to.be.true;
      expect(deltaDevBalance.eq(await arenaWithFee._choiceCreationFee())).to.be
        .true;
    });
  });
});
