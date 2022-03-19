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
    expect(arena.address).not.null;
  })

  it("Should fail to create arena with percentage fee more than 100%", async () => {
    await expect(deployArena(getInvalidArenaParams())).to.reverted;
  });

  it("Should create topic", async () => {
    let arena = await deployArena(getValidArenaParams());
  })

});
