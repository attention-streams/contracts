import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {Choice, Topic__factory} from "../typechain-types";
import { ethers } from "hardhat";
import { deployMockContract, MockContract } from "ethereum-waffle";

describe("Choice", async () => {
  let choice: Choice;
  let topic: MockContract;
  let admin: SignerWithAddress;
  let userA: SignerWithAddress;
  let userB: SignerWithAddress;
  let userC: SignerWithAddress;

  const feeRate = 1000; // 10% - scale of 10000

  before(async () => {
    [admin, userA, userB, userC] = await ethers.getSigners();
  });

  describe("Vote", async () => {
    before(async () => {
      const choiceFactory = await ethers.getContractFactory("Choice");
      topic = await deployMockContract(admin, Topic__factory.abi );

      choice = await choiceFactory.deploy(topic.address, feeRate, 10000);

      await topic.mock.currentCycle.returns(0);
    });

    it("should pass", async () => {
      // user A votes

      await choice.connect(userA).vote(10000);
    });
  });
});
