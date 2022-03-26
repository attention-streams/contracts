import hre from "hardhat";
import deploy_config from "./config";

// sleep time expects milliseconds
function sleep(time: number) {
  return new Promise((resolve) => setTimeout(resolve, time));
}

function isLocalNetwork(networkName: string) {
  return (
    deploy_config.local_networks.find((x) => x === networkName) !== undefined
  );
}

async function deployAndVerify(contractName: string, args: any[]) {
  let Contract = await hre.ethers.getContractFactory(contractName);

  console.log("[DEPLOY] Deploying contract...");
  let contract = await Contract.deploy(...args);
  console.log("[DEPLOY] Contract deployed at ", contract.address);

  if (!isLocalNetwork(hre.network.name)) {
    // wait a bit for etherscan to sync (60 sec)
    console.log("[DEPLOY] waiting 10 seconds for etherscan to sync...");
    await sleep(10 * 1000);

    console.log("[DEPLOY] Attempting to verify contract...");
    try {
      await hre.run("verify:verify", {
        address: contract.address,
        constructorArguments: args,
      });
      console.log("[DEPLOY] Contract verified!");
    } catch (e) {
      console.error("[DEPLOY] Failed to verify contract!");
      console.log(e);
    }
  }
  return contract;
}

export { deployAndVerify };
