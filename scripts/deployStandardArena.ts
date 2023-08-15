import hre, { upgrades } from "hardhat";
import { deployStandardArena } from "./deploy";

async function deploy() {
  const arena = await deployStandardArena();
  const implementation = upgrades.erc1967.getImplementationAddress(
    arena.address
  );

  await hre.run("verify:verify", {
    address: implementation,
    constructorArguments: [],
  });
  console.log("Contract verified!");
}

deploy()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
