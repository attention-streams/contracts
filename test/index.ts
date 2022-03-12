import { expect } from "chai";
import { ethers } from "hardhat";
import { BigNumber } from "ethers";
let arenaDeployParamsDict: {
  name: string;
  token: string;
  minContributionAmount: BigNumber;
  allowChoiceFunds: boolean;
  allowTopicFunds: boolean;
  arenaFeePercentage: BigNumber;
  choiceCreationFee: BigNumber;
  topicCreationFee: BigNumber;
};
let arena;

function getFlatParamsFromDict(paramsDict: any) {
  return Object.entries(paramsDict).map((e) => e[1]);
}

describe("Attention Stream Setup", () => {
  beforeEach(async () => {
    arenaDeployParamsDict = {
      name: "Test Arena",
      token: "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984",
      minContributionAmount: BigNumber.from(10),
      allowChoiceFunds: true,
      allowTopicFunds: true,
      arenaFeePercentage: BigNumber.from(10 * 10 ** 2),
      choiceCreationFee: BigNumber.from(10),
      topicCreationFee: BigNumber.from(10),
    };
  });
  it("Should fail to create arena with percentage fee more than 100%", async () => {
    const Arena = await ethers.getContractFactory("Arena");
    arenaDeployParamsDict.arenaFeePercentage = BigNumber.from(120 * 10 ** 2);
    const arenaDeployParams = getFlatParamsFromDict(arenaDeployParamsDict);
    // @ts-ignore
    const arena = Arena.deploy(...arenaDeployParams);
    await expect(arena).to.reverted;
  });

  it("Should create topic", async () => {
    const Topic = await ethers.getContractFactory('Topic');

  })

});
