import { BigNumber } from "ethers";
import helpers from "../scripts/helpers";
import { addChoice, addTopic, deployArena, vote } from "../scripts/deploy";
import { Arena, ERC20 } from "../typechain";
import {
  getValidArenaParams,
  getValidChoiceBParams,
  getValidChoiceParams,
  getValidTopicParams,
} from "./test.creations.data";
import { ethers } from "hardhat";
import { expect } from "chai";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

describe("test test", async () => {
  it("should pass", async () => {
    expect(1).to.equal(1);
  });
});
describe("Test Voting", async () => {
  let arena: Arena;
  let token: ERC20;
  let arenaFunds: SignerWithAddress;
  let topicFunds: SignerWithAddress;
  let choiceAFunds: SignerWithAddress;
  let choiceBFunds: SignerWithAddress;
  let voter1: SignerWithAddress;
  let voter2: SignerWithAddress;
  const topic: BigNumber = BigNumber.from(1);
  const choiceA: BigNumber = BigNumber.from(1);
  const choiceB: BigNumber = BigNumber.from(2);

  async function _deployArena() {
    const arenaParams = getValidArenaParams();
    arenaParams.token = token.address;
    arenaParams.funds = arenaFunds.address;
    arena = await deployArena(arenaParams);
    await arena.deployed();
  }

  async function _deployTopic() {
    const topicParams = getValidTopicParams();
    topicParams.funds = topicFunds.address;
    const _topicTx = await addTopic(arena, topicParams);
    await _topicTx.wait(1);
  }

  async function _deployTwoChoices() {
    const choiceAParams = getValidChoiceParams();
    choiceAParams.funds = choiceAFunds.address;

    const choiceBParams = getValidChoiceBParams();
    choiceBParams.funds = choiceBFunds.address;

    const _choiceATx = await addChoice(arena, topic, choiceAParams);
    const _choiceBTx = await addChoice(arena, topic, choiceBParams);

    await _choiceATx.wait(1);
    await _choiceBTx.wait(1);
  }

  async function _setupAttentionStreams() {
    token = await helpers.getTestVoteToken();
    await _deployArena();
    await _deployTopic();
    await _deployTwoChoices();
  }

  async function _fundVoters() {
    const _tx1 = await token.transfer(
      voter1.address,
      ethers.utils.parseEther("100")
    );
    await _tx1.wait(1);
    const _tx2 = await token.transfer(
      voter2.address,
      ethers.utils.parseEther("20")
    );
    await _tx2.wait(1);
  }

  before(async () => {
    [, arenaFunds, topicFunds, choiceAFunds, choiceBFunds, voter1, voter2] =
      await ethers.getSigners();
    await _setupAttentionStreams();
    await _fundVoters();
  });

  it("should fail to vote with less than min contribution amount", async () => {
    const tx = vote(arena, topic, choiceA, BigNumber.from(5), voter1);
    await expect(tx).to.be.revertedWith("Less than min contribution amount");
  });

  it("voter one puts 11 tokens on choice a", async () => {
    const tx = await vote(arena, topic, choiceA, BigNumber.from(11), voter1);
    await tx.wait(1);
    const positionInfo = await arena.choicePositionSummery(
      topic,
      choiceA,
      voter1.address
    );
    expect(positionInfo.tokens).to.equal(BigNumber.from(11));
    expect(positionInfo.shares).to.equal(BigNumber.from(0));
  });
});
