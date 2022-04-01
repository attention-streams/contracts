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

describe("Test Voting", async () => {
  let arena: Arena;
  let token: ERC20;
  let topic: BigNumber = BigNumber.from(1);
  let choice_a: BigNumber = BigNumber.from(1);
  let choice_b: BigNumber = BigNumber.from(2);

  before(async () => {
    token = await helpers.getTestVoteToken();
    let arenaParams = getValidArenaParams();
    arenaParams.token = token.address;
    arena = await deployArena(arenaParams);
    await arena.deployed();
    let _topicTx = await addTopic(arena, getValidTopicParams());
    await _topicTx.wait(1);
    let _choiceATx = await addChoice(arena, topic, getValidChoiceParams());
    await _choiceATx.wait(1);
    let _choiceBTx = await addChoice(arena, topic, getValidChoiceBParams());
    await _choiceBTx.wait(1);
  });

  it("should put a 12 tokens ");
});
