import { expect } from "chai";
import { ethers } from "hardhat";
import { BigNumber } from "ethers";

describe("Greeter", function () {
  it("Should return the new greeting once it's changed", async function () {
    const Greeter = await ethers.getContractFactory("Greeter");
    const greeter = await Greeter.deploy("Hello, world!");
    await greeter.deployed();

    expect(await greeter.greet()).to.equal("Hello, world!");

    const setGreetingTx = await greeter.setGreeting("Hola, mundo!");

    // wait until the transaction is mined
    await setGreetingTx.wait();

    expect(await greeter.greet()).to.equal("Hola, mundo!");
  });
});

describe("Attention Stream Setup", () => {
  it("Should create an arena", async () => {
    const Arena = await ethers.getContractFactory("Arena");
    const deployParams = {
      name: "Test Arena",
      description: "Test Arena Description",
      rules: ["r1", "r2", "r3"],
      token: "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984",
      minContributionAmount: BigNumber.from(10),
      allowChoiceFunds: true,
      allowTopicFunds: true,
      arenaFeePercentage: BigNumber.from(10),
      choiceCreationFee: BigNumber.from(10),
      topicCreationFee: BigNumber.from(10),
      tags: ["t1", "t2"],
    };

    const params = Object.entries(deployParams).map((e) => e[1]);

    // @ts-ignore
    const arena = await Arena.deploy(...params);
    await arena.deployed();
    const info = await arena.functions.info();

    expect(info).to.deep.include.members(params);
  });
});
