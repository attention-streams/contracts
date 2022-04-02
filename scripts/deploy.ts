// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import {
  ArenaParams,
  ChoiceParams,
  getFlatParamsFromDict,
  TopicParams,
} from "../test/test.creations.data";
import { Arena } from "../typechain";

async function deployAttentionToken() {
  const At = await ethers.getContractFactory("Attention");
  return await At.deploy();
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

  const params = getFlatParamsFromDict(_params);

  return {
    signer: _signer,
    params,
  };
}

async function deployArena(
  _params: ArenaParams,
  _signer?: SignerWithAddress
): Promise<Arena> {
  const { params, signer } = await getSingerAndParamsArray(_params, _signer);
  const Arena = await ethers.getContractFactory("Arena");

  // @ts-ignore
  return Arena.connect(signer).deploy(...getFlatParamsFromDict(params));
}

async function addTopic(
  _arena: Arena,
  _params: TopicParams,
  _signer?: SignerWithAddress
) {
  const { params, signer } = await getSingerAndParamsArray(_params, _signer);

  // @ts-ignore
  return _arena.connect(signer).addTopic(...params);
}

async function addChoice(
  _arena: Arena,
  _topicId: BigNumber,
  _params: ChoiceParams,
  _signer?: SignerWithAddress
) {
  const { params, signer } = await getSingerAndParamsArray(_params, _signer);

  // @ts-ignore
  return _arena.connect(signer).addChoice(_topicId, ...params);
}

export {
  deployAttentionToken,
  getSingerAndParamsArray,
  deployArena,
  addTopic,
  addChoice,
};

async function main() {}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
