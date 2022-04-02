import { BigNumber } from "ethers";
import helpers from "../scripts/helpers";
import { addChoice, addTopic, deployArena } from "../scripts/deploy";
import { Arena, ERC20 } from "../typechain";
import {
  getValidArenaParams,
  getValidChoiceBParams,
  getValidChoiceParams,
  getValidTopicParams,
} from "./test.creations.data";
import { ethers } from "hardhat";

describe("Test Voting", async () => {
  let arena: Arena;
  let token: ERC20;
  const [, arenaFunds, topicFunds, choiceAFunds, choiceBFunds, voter1, voter2] =
    await ethers.getSigners();
  const topic: BigNumber = BigNumber.from(1);
  const choice_a: BigNumber = BigNumber.from(1);
  const choice_b: BigNumber = BigNumber.from(2);

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
    await _setupAttentionStreams();
    await _fundVoters();
  });

  it("voter 1 should put a 1 token on choice a", async () => {
    // await voteOnChoice();
  });
});
