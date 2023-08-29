import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Choice, IERC20__factory, Topic__factory } from "../typechain-types";
import { ethers } from "hardhat";
import { deployMockContract, MockContract } from "ethereum-waffle";
import { expect } from "chai";

describe("Choice", async () => {
  let choice: Choice;
  let topic: MockContract;
  let token: MockContract;
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
      token = await deployMockContract(admin, IERC20__factory.abi);

      await topic.mock.contributorFee.returns(feeRate);
      await topic.mock.accrualRate.returns(10000);
      await topic.mock.token.returns(token.address);
      await topic.mock.currentCycleNumber.returns(0);

      choice = await choiceFactory.deploy(topic.address);
    });

    it("after votes and withdraws, tokens must be zero", async () => {
      await token.mock.transferFrom.returns(true); // allow all transfers from users
      await token.mock.transfer.returns(true); // allow all transfers to users

      await choice.connect(userA).contribute(10000);
      await choice.connect(userB).contribute(10000);

      await topic.mock.currentCycleNumber.returns(1);
      await choice.connect(userA)["withdraw()"]();
      await choice.connect(userB)["withdraw()"]();

      const tokens = await choice.tokens();

      expect(tokens).to.equal(0);
    });

    describe("Vote", async () => {});
  });
});
