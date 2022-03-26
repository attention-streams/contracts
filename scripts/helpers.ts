import hre from "hardhat";
import config from "../networks.config";
import { deployAttentionToken } from "./deploy";

function isLocalNetwork() {
  return (
    config.local_networks.find((x) => x === hre.network.name) !== undefined
  );
}

async function getTestVoteToken(): Promise<string> {
  if (hre.network.name === "rinkeby") return config.rinkeby.voting_token;
  return (await deployAttentionToken()).address;
}

export default {
  getTestVoteToken,
};
