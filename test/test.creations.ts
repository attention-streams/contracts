import { expect } from "chai";
import { ethers } from "hardhat";
import { deployArena } from "../scripts/deploy";
import {
  getInvalidArenaParams,
  getValidArenaParams,
  getFlatParamsFromDict
} from "./mock.data";


describe("Attention Stream Setup", () => {
  it("should create arena", async () => {
    const arena = await deployArena(getValidArenaParams());
    const arena_info = await arena.functions.info()
    expect(arena_info).deep.include.members(getFlatParamsFromDict(getValidArenaParams()))
    expect(arena.address).not.null;
  })

  it("Should fail to create arena with percentage fee more than 100%", async () => {
    await expect(deployArena(getInvalidArenaParams())).to.be.reverted;
  });

  it("Should create topic", async () => {
    const arena = await deployArena(getValidArenaParams());
  })

});
