import { expect } from "chai";
import { ethers } from "hardhat";
import { addTopic, deployArena } from "../scripts/deploy";
import { Arena } from "../typechain";
import {
  getInvalidArenaParams,
  getValidArenaParams,
  getFlatParamsFromDict,
  getValidTopicParams
} from "./mock.data";

let arena: Arena;

describe("Attention Stream Setup", () => {
  before(async () => {
    // create arena
    arena = await deployArena(getValidArenaParams());
  })
  it("should validate the default arena", async () => {
    const arena_info = await arena.functions.info()
    expect(arena_info).deep.include.members(getFlatParamsFromDict(getValidArenaParams()))
    expect(arena.address).not.null;
  })

  it("Should fail to create arena with percentage fee more than 100%", async () => {
    await expect(deployArena(getInvalidArenaParams())).to.be.reverted;
  });

  it("Should create the first valid topic", async () => {
    let tx = await addTopic(arena, getValidTopicParams());
    tx.wait(1);
    let nextId = await arena.topicData.call('nextTopicId')
    expect(nextId).to.be.equal(1)
  })
  it("Should create the second valid topic", async () => {
    let tx = await addTopic(arena, getValidTopicParams());
    tx.wait(1);
    let nextId = await arena.topicData.call('nextTopicId')
    expect(nextId).to.be.equal(2)
  })
  it("Should fail to create topic with topic fee more than 5% (limited by arena)", async () => {
    let params = getValidTopicParams();
    params.topicFeePercentage = 1000 // 10 %
    let tx = addTopic(arena, params);
    await expect(tx).to.be.revertedWith("Max topic fee exceeded");

  })
  it("should fail to create topic with choice fee exceeding max choice fee defined by arena", async () => {
    let params = getValidTopicParams();
    params.maxChoiceFundFeePercentage = 3100 // 31 %
    let tx = addTopic(arena, params);
    await expect(tx).to.be.revertedWith("Max choice fee exceeded");
  })

  it("should fail to crate topic with arenaFee + topicFee + contributorFee > 100%", async () => {
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
    topicParams.prevContributorsFee = 6500 // 65 %

    // current arrangement: 10(arena) + 30(topic) + 65(contributor) = 105 %

    let tx = addTopic(arena, topicParams);

    await expect(tx).to.be.revertedWith("arenaFee + topicFee + contributorFee exceeded 100%")

  })

});
