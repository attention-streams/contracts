// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";
import { getValidArenaParams, getFlatParamsFromDict } from "../test/mock.data";

async function deployArena() {
  const Arena = await ethers.getContractFactory("Arena");
  let params = getFlatParamsFromDict(getValidArenaParams());

  //@ts-ignore
  const arena = await Arena.deploy(...getFlatParamsFromDict(params));
  return arena
}

async function main() {
  await deployArena();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
