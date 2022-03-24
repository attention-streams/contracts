// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";
import { getValidArenaParams, getFlatParamsFromDict, ArenaParams, TopicParams } from "../test/mock.data";
import { Arena } from "../typechain";

export async function deployAttentionToken() {
  const At = await ethers.getContractFactory("Attention");
  const at = await At.deploy()

  return at;
}

export async function deployArena(params: ArenaParams): Promise<Arena> {
  const Arena = await ethers.getContractFactory("Arena");
  let _params = getFlatParamsFromDict(params);
  //@ts-ignore
  return Arena.deploy(...getFlatParamsFromDict(_params));
}

export async function addTopic(arena: Arena, params: TopicParams) {
  let _params = getFlatParamsFromDict(params);
  //@ts-ignore
  let topicId = await arena.functions.addTopic(..._params)
  topicId.wait(1);
  return topicId;
}

export async function deployMain() {
  let at = await deployAttentionToken();
  let arena = await deployArena(getValidArenaParams());
  console.log(at.address);
  console.log(arena.address)
}

async function main() {

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
