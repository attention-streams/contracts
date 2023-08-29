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
    async function allowAllTokenTransfers() {
      await token.mock.transferFrom.returns(true); // allow all transfers from users
      await token.mock.transfer.returns(true); // allow all transfers to users
    }

    beforeEach(async () => {
      const choiceFactory = await ethers.getContractFactory("Choice");
      topic = await deployMockContract(admin, Topic__factory.abi);
      token = await deployMockContract(admin, IERC20__factory.abi);

      await topic.mock.contributorFee.returns(feeRate);
      await topic.mock.accrualRate.returns(10000);
      await topic.mock.token.returns(token.address);
      await topic.mock.currentCycleNumber.returns(0);

      choice = await choiceFactory.deploy(topic.address);
    });

    it("after contribution and withdraws, tokens must be zero", async () => {
      await allowAllTokenTransfers();

      await choice.connect(userA).contribute(10000);
      await choice.connect(userB).contribute(10000);

      let tokens = await choice.tokens();

      expect(tokens).to.equal(20000);

      await topic.mock.currentCycleNumber.returns(1);
      await choice.connect(userA)["withdraw()"]();
      await choice.connect(userB)["withdraw()"]();

      tokens = await choice.tokens();

      expect(tokens).to.equal(0);
    });

    it("should record contribution", async () => {
      await allowAllTokenTransfers();
      await choice.connect(userA).contribute(10000);
      const userAPosition = await choice.positionsByAddress(userA.address, 0);

      expect(userAPosition.cycleIndex).to.equal(0);
      expect(userAPosition.tokens).to.equal(10000);
      expect(userAPosition.exists).to.equal(true);
    });

    it("should properly transfer positions", async () => {
      await allowAllTokenTransfers();

      await choice.connect(userA).contribute(10000);

      let userAPosition = await choice.positionsByAddress(userA.address, 0);
      let userAPositionsLength = await choice.positionsLength(userA.address);

      expect(userAPositionsLength).to.equal(1);
      expect(userAPosition.tokens).to.equal(10000); // position exists before transfer
      expect(userAPosition.exists).to.equal(true);

      await expect(choice.positionsByAddress(userB.address, 0)).to.be.reverted; // position does not exist before transfer

      await choice.connect(userA)["transferPosition(address)"](userB.address);

      userAPosition = await choice.positionsByAddress(userA.address, 0); // position does not exist after transfer

      const userBPosition = await choice.positionsByAddress(userB.address, 0);

      expect(userAPosition.tokens).to.equal(0); // position does not exist after transfer
      expect(userAPosition.exists).to.equal(false);

      expect(userBPosition.tokens).to.equal(10000); // position exists after transfer
      expect(userBPosition.exists).to.equal(true);
    });

    it("should properly transfer positions with multiple positions", async () => {
      await allowAllTokenTransfers();

      await choice.connect(userA).contribute(10000);
      await choice.connect(userA).contribute(20000);

      let userAPosition0 = await choice.positionsByAddress(userA.address, 0);
      let userAPosition1 = await choice.positionsByAddress(userA.address, 1);
      let userAPositionsLength = await choice.positionsLength(userA.address);

      expect(userAPositionsLength).to.equal(2);
      expect(userAPosition0.tokens).to.equal(10000); // position exists before transfer
      expect(userAPosition0.exists).to.equal(true);
      expect(userAPosition1.tokens).to.equal(20000); // position exists before transfer
      expect(userAPosition1.exists).to.equal(true);

      await expect(choice.positionsByAddress(userB.address, 0)).to.be.reverted; // position does not exist before transfer

      await choice.connect(userA).transferPositions(userB.address, [0, 1]);

      userAPosition0 = await choice.positionsByAddress(userA.address, 0); // position does not exist after transfer
      userAPosition1 = await choice.positionsByAddress(userA.address, 1);

      const userBPosition0 = await choice.positionsByAddress(userB.address, 0);
      const userBPosition1 = await choice.positionsByAddress(userB.address, 1);

      expect(userAPosition0.exists).to.equal(false);
      expect(userAPosition1.exists).to.equal(false);

      expect(userBPosition0.tokens).to.equal(10000); // position exists after transfer
      expect(userBPosition0.exists).to.equal(true);

      expect(userBPosition1.tokens).to.equal(20000); // position exists after transfer
      expect(userBPosition1.exists).to.equal(true);
    });
  });
});
