// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";
import { ContractType } from "hardhat/internal/hardhat-network/stack-traces/model";
import { getValidArenaParams, getFlatParamsFromDict, ArenaParams, TopicParams } from "../test/mock.data";
import { Arena } from "../typechain";

export async function deployArena(params: ArenaParams): Promise<Arena> {
  const Arena = await ethers.getContractFactory("Arena");
  let _params = getFlatParamsFromDict(params);

  //@ts-ignore
  return Arena.deploy(...getFlatParamsFromDict(_params));
}

export async function addTopic(params: TopicParams) {

}

async function main() {
  await deployArena(getValidArenaParams());
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
