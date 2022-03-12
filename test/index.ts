import { expect } from "chai";
import { ethers } from "hardhat";
import { BigNumber } from "ethers";

const arenaDeployParamsDict = {
  name: "Test Arena",
  token: "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984",
  minContributionAmount: BigNumber.from(10),
  allowChoiceFunds: true,
  allowTopicFunds: true,
  arenaFeePercentage: BigNumber.from(10),
  choiceCreationFee: BigNumber.from(10),
  topicCreationFee: BigNumber.from(10),
};

function getFlatParamsFromDict(paramsDict: any) {
  return Object.entries(paramsDict).map((e) => e[1]);
}

describe("Attention Stream Setup", () => {
  it("Should create an arena", async () => {
    const Arena = await ethers.getContractFactory("Arena");
    const arenaDeployParams = getFlatParamsFromDict(arenaDeployParamsDict);
    // @ts-ignore
    const arena = await Arena.deploy(...arenaDeployParams);
    await arena.deployed();
    const info = await arena.functions.info();
    expect(info).to.deep.include.members(arenaDeployParams);
  });
});
