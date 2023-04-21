require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");

// Load environment variables from .env file
require("dotenv").config();

// Define the networks
const networks = {
  hardhat: {},
  rinkeby: {
    url: `https://rinkeby.infura.io/v3/${process.env.INFURA_PROJECT_ID}`,
    accounts: [process.env.PRIVATE_KEY],
  },
  taiko: {
    url: "https://l2rpc.hackathon.taiko.xyz",
    accounts: [process.env.PRIVATE_KEY],
  },
  sepolia: {
    url: "https://rpc.sepolia.org",
    accounts: [process.env.PRIVATE_KEY],
  },
};

// Define the solidity compiler version and optimizer settings
const solidityVersion = "0.8.9";
const optimizerEnabled = true;
const optimizerRuns = 200;

// Define the configuration
const config = {
  solidity: {
    version: solidityVersion,
    optimizer: {
      enabled: optimizerEnabled,
      runs: optimizerRuns,
    },
  },
  networks,
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};

// Export the configuration
module.exports = config;
