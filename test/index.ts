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

function getFlatParamsFromDict(paramsDict: any) {
  return Object.entries(paramsDict).map((e) => e[1]);
}

describe("Attention Stream Setup", () => {
  beforeEach(() => {
    arenaDeployParamsDict = {
      name: "Test Arena",
      token: "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984",
      minContributionAmount: BigNumber.from(10),
      allowChoiceFunds: true,
      allowTopicFunds: true,
      arenaFeePercentage: BigNumber.from(10),
      choiceCreationFee: BigNumber.from(10),
      topicCreationFee: BigNumber.from(10),
    };
  });
  it("Should create an arena", async () => {
    const Arena = await ethers.getContractFactory("Arena");
    const arenaDeployParams = getFlatParamsFromDict(arenaDeployParamsDict);
    // @ts-ignore
    const arena = await Arena.deploy(...arenaDeployParams);
    await arena.deployed();
    const info = await arena.functions.info();
    expect(info).to.deep.include.members(arenaDeployParams);
  });
  it("Should fail to create arena with percentage fee more than 100%", async () => {
    const Arena = await ethers.getContractFactory("Arena");
    arenaDeployParamsDict.arenaFeePercentage = BigNumber.from(120);
    const arenaDeployParams = getFlatParamsFromDict(arenaDeployParamsDict);
    // @ts-ignore
    const arena = Arena.deploy(...arenaDeployParams);
    await expect(arena).to.reverted;
  });
});
