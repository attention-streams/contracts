import { expect } from "chai";
import { ethers } from "hardhat";
import { BigNumber } from "ethers";
import { getInvalidArenaParams, getValidArenaParams, getFlatParamsFromDict } from "./mock.data";


describe("Attention Stream Setup", () => {
  it("should create arena", async () => {
    const Arena = await ethers.getContractFactory("Arena");
    const arenaDeployParams = getFlatParamsFromDict(getValidArenaParams());

    // @ts-ignore
    const arena = await Arena.deploy(...arenaDeployParams);
    expect(arena.address).not.null;

  })

  it("Should fail to create arena with percentage fee more than 100%", async () => {
    const Arena = await ethers.getContractFactory("Arena");
    const arenaDeployParams = getFlatParamsFromDict(getInvalidArenaParams());

    // @ts-ignore
    const arena = Arena.deploy(...arenaDeployParams);
    await expect(arena).to.reverted;
  });

  it("Should create topic", async () => {
    const Topic = await ethers.getContractFactory("Topic");
  })

});
