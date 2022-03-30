// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { any } from "hardhat/internal/core/params/argumentTypes";
import {
  ArenaParams,
  getFlatParamsFromDict,
  getValidArenaParams,
  TopicParams,
  ChoiceParams,
} from "../test/test.creations.data";
import { Arena } from "../typechain";

export async function deployAttentionToken() {
  const At = await ethers.getContractFactory("Attention");
  const at = await At.deploy();
  return at;
}

interface ParamsSigner {
  signer: SignerWithAddress;
  params: any[];
}

async function getSingerAndParamsArray(
  _params: any,
  _signer?: SignerWithAddress
): Promise<ParamsSigner> {
  if (_signer === undefined) [_signer] = await ethers.getSigners();

  let params = getFlatParamsFromDict(_params);

  return {
    signer: _signer,
    params,
  };
}

export async function deployArena(
  _params: ArenaParams,
  _signer?: SignerWithAddress
): Promise<Arena> {
  let { params, signer } = await getSingerAndParamsArray(_params, _signer);
  const Arena = await ethers.getContractFactory("Arena");

  //@ts-ignore
  return Arena.connect(signer).deploy(...getFlatParamsFromDict(params));
}

export async function addTopic(
  _arena: Arena,
  _params: TopicParams,
  _signer?: SignerWithAddress
) {
  let { params, signer } = await getSingerAndParamsArray(_params, _signer);

  //@ts-ignore
  let tx = _arena.connect(signer).addTopic(...params);
  return tx;
}

export async function addChoice(
  _arena: Arena,
  _topicId: BigNumber,
  _params: ChoiceParams,
  _signer?: SignerWithAddress
) {
  let { params, signer } = await getSingerAndParamsArray(_params, _signer);

  //@ts-ignore
  let tx = _arena.connect(signer).addChoice(_topicId, ...params);
  return tx;
}

export async function deployMain() {
  let at = await deployAttentionToken();
  let arena = await deployArena(getValidArenaParams());
  console.log(at.address);
  console.log(arena.address);
}

async function main() {}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
