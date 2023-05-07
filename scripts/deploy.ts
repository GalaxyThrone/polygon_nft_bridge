// Import dependencies
const hre = require("hardhat");

async function main() {
  // Deploy the openAccessNFTBridge contract

  const OpenAccessNFTBridge = await hre.ethers.getContractFactory(
    "GalaxyBridge"
  );
  const openAccessNFTBridge = await OpenAccessNFTBridge.deploy(1);
  await openAccessNFTBridge.deployed();
  console.log(
    "GalaxyBridge deployed to:",
    openAccessNFTBridge.address
  );
}

// Run the deploy script
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
