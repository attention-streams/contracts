import { expect, util } from "chai";
import { BigNumber, utils } from "ethers";
import helpers from '../scripts/helpers';

import { addTopic, deployArena, deployAttentionToken } from "../scripts/deploy";
import { Arena, ERC20 } from "../typechain";
import {
  getValidArenaParams,
  getFlatParamsFromDict,
  getValidTopicParams,
  TopicParams
} from "./mock.data";
import { ethers } from "hardhat";


describe("Attention Stream Setup", () => {
  describe("Arena creation", () => {
    let arena: Arena;
    it("Should deploy arena", async () => {
      arena = await deployArena(getValidArenaParams());
      expect(arena.address).to.not.be.null;
    })
    it("Should properly retrieve arena info", async () => {
      const arena_info = await arena.functions.info()
      expect(arena_info).deep.include.members(getFlatParamsFromDict(getValidArenaParams()))
      expect(arena.address).not.null;
    })

    it("Should fail to create arena with percentage fee more than 100%", async () => {
      let params = getValidArenaParams()
      params.arenaFeePercentage = 10100
      await expect(deployArena(params)).to.be.reverted;
    })
  })
  describe("Topic Creation", () => {
    describe.skip("skipping", () => { });

    let arena: Arena;
    before(async () => {
      // create arena
      arena = await deployArena(getValidArenaParams());
    })
    it("Should create the first valid topic", async () => {
      let tx = await addTopic(arena, getValidTopicParams());
      await tx.wait(1);
      let nextId = await arena._topicData.call('nextTopicId')
      expect(nextId).to.be.equal(1)

    })
    it("Should create the second valid topic", async () => {
      let params = getValidTopicParams()
      params.cycleDuration = 10;
      let tx = await addTopic(arena, params);
      await tx.wait(1);
      let nextId = await arena._topicData.call('nextTopicId')
      expect(nextId).to.be.equal(2)
    })
    it("Should properly return topic 1 info", async () => {
      let info = await arena.getTopicInfoById(1);
      let params = getValidTopicParams()
      expect(info).to.deep.include.members(getFlatParamsFromDict(params))
    })
    it("Should properly return topic 2 info", async () => {
      let info = await arena.getTopicInfoById(2);
      let params = getValidTopicParams()
      params.cycleDuration = 10;
      expect(info).to.deep.include.members(getFlatParamsFromDict(params))
    })
    it("Should fail to create topic with topic fee more than 5% (limited by arena)", async () => {
      let params = getValidTopicParams();
      params.topicFeePercentage = 1000 // 10 %
      let tx = addTopic(arena, params);
      await expect(tx).to.be.revertedWith("Max topic fee exceeded");

    })
    it("Should fail to create topic with choice fee exceeding max choice fee defined by arena", async () => {
      let params = getValidTopicParams();
      params.maxChoiceFeePercentage = 3100 // 31 %
      let tx = addTopic(arena, params);
      await expect(tx).to.be.revertedWith("Max choice fee exceeded");
    })
    it("Should fail to create topic with fundingPercentage more than 100%", async () => {
      let params = getValidTopicParams()
      params.fundingPercentage = 10100;
      let tx = addTopic(arena, params);
      await expect(tx).to.be.revertedWith("funding percentage exceeded 100%");
    })
    it("Should fail to crate topic with arenaFee + topicFee + contributorFee > 100%", async () => {
      let arenaParams = getValidArenaParams()
      /* 
      setting max topic fee and choice fee to 100% means 
      arena should validate that 
      arenaFee + topicFee + contributorFee is less than 100 %

      arena fee is 10%
      */
      arenaParams.maxTopicFeePercentage = 10000 // 100 %
      arenaParams.maxChoiceFeePercentage = 10000 // 100 %

      let arena: Arena = await deployArena(arenaParams);

      let topicParams = getValidTopicParams()
      topicParams.topicFeePercentage = 3000 // 30 %
      topicParams.prevContributorsFeePercentage = 6500 // 65 %

      // current arrangement: 10(arena) + 30(topic) + 65(contributor) = 105 %

      let tx = addTopic(arena, topicParams);

      await expect(tx).to.be.revertedWith("accumulative fees exceeded 100%")

    })
  })

  describe("Topic Creation Fee", async () => {
    let arena: Arena;
    let token: ERC20;

    it("Should create arena fee topic creation fee of 10 tokens", async () => {
      let testVoteToken = await helpers.getTestVoteToken()
      token = await ethers.getContractAt("ERC20", testVoteToken)
      let params = getValidArenaParams();
      params.topicCreationFee = utils.parseEther("10");
      params.token = testVoteToken;
      arena = await deployArena(params);
      let info = await arena.info()
      expect(info.topicCreationFee).to.be.equal(utils.parseEther("10"));
    })

    it("should fail to create topic if contract can't spend funds", async () => {
      let [owner, dev] = await ethers.getSigners()
      let topicParams = getValidTopicParams()
      let tx = addTopic(arena, topicParams, dev);
      await expect(tx).to.be.revertedWith("ERC20: insufficient allowance");
    })
    it("should fail to create topic if balance is low", async () => {
      let [owner, dev] = await ethers.getSigners();
      let topicCreationFee: BigNumber = await arena._topicCreationFee();

      // approve the contract to spend funds
      await token.connect(dev).approve(arena.address, topicCreationFee);
      let tx = addTopic(arena, getValidTopicParams(), dev);
      await expect(tx).to.be.revertedWith("ERC20: transfer amount exceeds balance");
    
    })
    it("should subtract fee amount from creator and add it to arena funds", async () => {
      let [owner, dev] = await ethers.getSigners();
      let topicCreationFee: BigNumber = await arena._topicCreationFee();
      
      // transfer some funds from owner to dev
      await token.connect(owner).transfer(dev.address, topicCreationFee);
      
      // approve the contract to spend funds
      await token.connect(dev).approve(arena.address, topicCreationFee);

      let devBalanceBefore: BigNumber = await token.balanceOf(dev.address);
      let arenaBalanceBefore: BigNumber = await token.balanceOf(arena.address);

      let topicParams = getValidTopicParams();
      await addTopic(arena, topicParams, dev);

      let devBalanceAfter: BigNumber = await token.balanceOf(dev.address);
      let arenaBalanceAfter: BigNumber = await token.balanceOf(arena.address);

      let deltaDevBalance: BigNumber = devBalanceBefore.sub(devBalanceAfter);
      let deltaArenaBalance: BigNumber = arenaBalanceAfter.sub(arenaBalanceBefore);

      expect(deltaDevBalance.eq(deltaArenaBalance)).to.be.true;
      expect(deltaArenaBalance.eq(topicCreationFee)).to.be.true;

    })

  })

});
