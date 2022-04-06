import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber } from "ethers";
import { parseEther } from "ethers/lib/utils";
import { ethers, network } from "hardhat";
import {
  ArenaParams,
  ChoiceParams,
  getFlatParamsFromDict,
  getValidArenaParams,
  getValidChoiceParams,
  getValidTopicParams,
  TopicParams,
} from "../test/test.creations.data";
import { Arena } from "../typechain";
import { wallets } from "./rinkeby.wallets";

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
  const signer = await getSigner(_signer);
  const Arena = await ethers.getContractFactory("Arena");
  return Arena.connect(signer).deploy(_params);
}

async function addTopic(
  _arena: Arena,
  _params: TopicParams,
  _signer?: SignerWithAddress
) {
  const signer = await getSigner(_signer);
  return _arena.connect(signer).addTopic(_params);
}

async function addChoice(
  _arena: Arena,
  _topicId: BigNumber,
  _params: ChoiceParams,
  _signer?: SignerWithAddress
) {
  const signer = await getSigner(_signer);
  return _arena.connect(signer).addChoice(_topicId, _params);
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

async function deployStandardArena() {
  let params = getValidArenaParams();
  params._token = "0x93055D4D59CE4866424E1814b84986bFD44920b9";
  let t = await deployArena(params);
  await t.deployed();
  console.log("Deployed at ", t.address);
}

async function addStandardTopic(arena: Arena) {
  let params = getValidTopicParams();
  params._cycleDuration = 2;
  let t = await addTopic(arena, params);
  await t.wait(1);
  console.log("Topic Added");
}

async function addChoiceA(arena: Arena, topicId: BigNumber) {
  let params = getValidChoiceParams();
  let t = await addChoice(arena, topicId, params);
  await t.wait(1);
  console.log("Choice Added");
}

async function generate100wallets() {
  let wallets = [];
  for (let i = 0; i < 100; i++) {
    let w = ethers.Wallet.createRandom();
    wallets.push(w.mnemonic.phrase);
  }
  console.log(wallets);
}

async function loadRinkebyWallets() {
  let ethWallets = [];
  let [owner] = await ethers.getSigners();
  for (let phrase of wallets) {
    let _w = ethers.Wallet.fromMnemonic(phrase);
    let w = new ethers.Wallet(_w.privateKey, owner.provider);
    ethWallets.push(w);
  }

  return ethWallets;
}

async function fundRinkebyWallets() {
  let [owner] = await ethers.getSigners();

  let token = await ethers.getContractAt(
    "ERC20",
    "0x93055D4D59CE4866424E1814b84986bFD44920b9"
  );
  let theWallets = await loadRinkebyWallets();
  for (let i = 0; i < theWallets.length; i++) {
    let w = theWallets[i];
    await token.connect(owner).transfer(w.address, parseEther("0.01"));
    console.log(i);
  }
}

async function fundWalletsWithTestEther() {
  let [owner] = await ethers.getSigners();

  let theWallets = await loadRinkebyWallets();
  for (let i = 0; i < theWallets.length; i++) {
    let w = theWallets[i];
    await owner.sendTransaction({
      to: w.address,
      value: parseEther("0.01"),
    });
    console.log(i);
  }
}

async function approveContractToSpendToken() {
  let [owner] = await ethers.getSigners();
  let theWallets = await loadRinkebyWallets();
  let token = await ethers.getContractAt(
    "ERC20",
    "0x93055D4D59CE4866424E1814b84986bFD44920b9"
  );
  for (let i = 0; i < theWallets.length; i++) {
    let w = theWallets[i];
    await token
      .connect(w)
      .approve("0x99b4ba32a258Add555B751C8C8B6a6673a284247", parseEther("1"));

    console.log(i);
  }
}

async function main() {
  if (network.name == "rinkeby") {
    let [owner] = await ethers.getSigners();
    let arenaAddress = "0x99b4ba32a258Add555B751C8C8B6a6673a284247";
    let arena = await ethers.getContractAt("Arena", arenaAddress);
    let topicId = BigNumber.from(0);
    let choiceId = BigNumber.from(0);
    let theWallets = await loadRinkebyWallets();
    for (let i = 0; i < 100; i += 2) {
      let v1 = await arena
        .connect(theWallets[i])
        .vote(topicId, choiceId, parseEther("0.001"));
      let v2 = await arena
        .connect(theWallets[i + 1])
        .vote(topicId, choiceId, parseEther("0.001"));

      await v2.wait(2);
      console.log(i);
    }
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
