const { ethers } = require('hardhat');

async function main() {

    
  const contractAddress = '0x148cff8FD012eefB61128d3fFa23CFA744E63163'; // The address of your contract
  const privateKey = process.env.PRIVATE_KEY; // Your private key from the .env file
  const sisterContractAddress = '0x9bF56347Cf15e37A0b85Dc269b65D2b10399be96'; // The address of the sister bridge contract
  
  // Set up the signer with your private key connected to the provider from the Hardhat config
  const signer = new ethers.Wallet(privateKey, ethers.provider);

  // Load the contract using the ethers library
  const contract = await ethers.getContractAt('openAccessNFTBridge', contractAddress, signer);

  // Call the addSisterBridgeContract function on the contract
  const tx = await contract.addSisterBridgeContract(sisterContractAddress);

  console.log('Transaction hash:', tx.hash);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
