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

async function getSigner(
  _signer: SignerWithAddress | undefined
): Promise<SignerWithAddress> {
  if (_signer === undefined) {
    const [_theSigner] = await ethers.getSigners();
    return _theSigner;
  }
  return _signer;
}

async function getSingerAndParamsArray(
  _params: any,
  _signer?: SignerWithAddress
): Promise<ParamsSigner> {
  const params = getFlatParamsFromDict(_params);
  return {
    signer: await getSigner(_signer),
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

  return _arena.connect(signer).addTopic(_params);
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

async function vote(
  _arena: Arena,
  _topicId: BigNumber,
  _choiceId: BigNumber,
  _amount: BigNumber,
  _signer?: SignerWithAddress
) {
  return _arena
    .connect(await getSigner(_signer))
    .vote(_topicId, _choiceId, _amount);
}

export {
  deployAttentionToken,
  getSingerAndParamsArray,
  deployArena,
  addTopic,
  addChoice,
  vote,
};

async function main() {}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
