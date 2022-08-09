import * as dotenv from "dotenv";

import { HardhatUserConfig, task } from "hardhat/config";

import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-ethers";
import "@openzeppelin/hardhat-upgrades";
require("solidity-coverage");

dotenv.config();

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

let accounts: string[] = [];

function setAccountIfExists(account: string | undefined) {
  if (account !== undefined) accounts.push(account);
}

setAccountIfExists(process.env.PRIVATE_KEY_OWNER);
setAccountIfExists(process.env.PRIVATE_KEY_DEV);
setAccountIfExists(process.env.PRIVATE_KEY_USER);

const config = {
  solidity: {
    version: "0.8.4",
    allowUnlimitedContractSize: true,
    optimizer: {
      enabled: true,
      runs: 5000,
      allowUnlimitedContractSize: true,

      details: { yul: false },
    },
  },
  allowUnlimitedContractSize: true,

  networks: {
    local: {
      url: "http://127.0.0.1:8545",
      allowUnlimitedContractSize: true,
      accounts: {
        mnemonic:
          "myth like bonus scare over problem client lizard pioneer submit female collect",
        initialIndex: 0,
        // Ref: https://developers.rsk.co/rsk/architecture/account-based/#derivation-path-info
        path: "m/44'/60'/0'/0/",
        count: 10,
      },
    },
    rinkeby: {
      url: process.env.RINKEBY_URL !== undefined ? process.env.RINKEBY_URL : "",
      accounts: accounts,
      gas: "auto",
      gasPrice: "auto",
    },
    goerli: {
      url: process.env.GOERLI_URL !== undefined ? process.env.GOERLI_URL : "",
      accounts: accounts,
      gas: "auto",
      gasPrice: "auto",
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  mocha: { timeout: 10 * 60 * 1000 },
};

export default config;
