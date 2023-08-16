import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Choice, Topic__factory } from "../typechain-types";
import { ethers } from "hardhat";
import { deployMockContract, MockContract } from "ethereum-waffle";
import { expect } from "chai";

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
      topic = await deployMockContract(admin, Topic__factory.abi);

      await topic.mock.choiceFeeRate.returns(feeRate);
      await topic.mock.accrualRate.returns(10000);

      choice = await choiceFactory.deploy(topic.address);

      await topic.mock.currentCycle.returns(0);
    });

    it("after votes and withdraws, tokens must be zero", async () => {
      await topic.mock.currentCycle.returns(0);
      await choice.connect(userA).vote(10000);
      await choice.connect(userB).vote(10000);

      await topic.mock.currentCycle.returns(1);
      await choice.connect(userA).withdraw(0);
      await choice.connect(userB).withdraw(0);

      const tokens = await choice.tokens();

      expect(tokens).to.equal(0);
    });
  });
});
