import hre, { ethers } from "hardhat";
import config from "../networks.config";
import { deployAttentionToken } from "./deploy";
import { ERC20 } from "../typechain";

function isLocalNetwork() {
  return (
    config.local_networks.find((x) => x === hre.network.name) !== undefined
  );
}

async function getTestVoteTokenAddress(): Promise<string> {
  if (hre.network.name === "rinkeby") return config.rinkeby.voting_token;
  return (await deployAttentionToken()).address;
}

async function getTestVoteToken(): Promise<ERC20> {
  let tokenAddress = await getTestVoteTokenAddress();
  return await ethers.getContractAt("ERC20", tokenAddress);
}

export default {
  getTestVoteTokenAddress,
  getTestVoteToken,
};
