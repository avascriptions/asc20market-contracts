import { ethers, upgrades } from 'hardhat'

const exchangeAddress = '0x24e24277e2FF8828d5d2e278764CA258C22BD497';

async function main() {
  
  const [ deployer ] = await ethers.getSigners();
  console.log("Deployer address", deployer.address);
  console.log("Exchange address", exchangeAddress);

  const ASC20Market = await ethers.getContractFactory("ASC20Market");
  const newAsc20Market = await upgrades.upgradeProxy(exchangeAddress, ASC20Market);
  
  const asc20Market = await newAsc20Market.deployed();
  console.log("ASC20Market address ", asc20Market.address);

  console.log('completed.');

}

main();
