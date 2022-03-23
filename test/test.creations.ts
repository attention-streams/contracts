import { expect } from "chai";
import { ethers } from "hardhat";
import { addTopic, deployArena } from "../scripts/deploy";
import { Arena } from "../typechain";
import {
  getInvalidArenaParams,
  getValidArenaParams,
  getFlatParamsFromDict,
  getValidTopicParams,
  TopicParams
} from "./mock.data";


describe("Attention Stream Setup", () => {
  describe("Arena creation", () => {
    let arena: Arena;
    it("Should create arena", async () => {
      arena = await deployArena(getValidArenaParams());
    })
    it("Should properly retrieve arena info", async () => {
      const arena_info = await arena.functions.info()
      expect(arena_info).deep.include.members(getFlatParamsFromDict(getValidArenaParams()))
      expect(arena.address).not.null;
    })

    it("Should fail to create arena with percentage fee more than 100%", async () => {
      await expect(deployArena(getInvalidArenaParams())).to.be.reverted;
    });
  })
  describe("Topic Creation", () => {
    let arena: Arena;
    before(async () => {
      // create arena
      arena = await deployArena(getValidArenaParams());

    })
    it("Should create the first valid topic", async () => {
      let tx = await addTopic(arena, getValidTopicParams());
      tx.wait(1);
      let nextId = await arena._topicData.call('nextTopicId')
      expect(nextId).to.be.equal(1)

    })
    it("Should create the second valid topic", async () => {
      let params = getValidTopicParams()
      params.cycleDuration = 10;
      let tx = await addTopic(arena, params);
      tx.wait(1);
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

});
