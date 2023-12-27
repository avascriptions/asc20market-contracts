import { ethers, upgrades } from 'hardhat'

async function main() {
  
  const [ deployer ] = await ethers.getSigners();
  console.log("Deployer address", deployer.address);

  const ASC20Market = await ethers.getContractFactory("ASC20Market");
  const asc20MarketProxy = await upgrades.deployProxy(ASC20Market);
  
  const asc20Market = await asc20MarketProxy.deployed();
  console.log("ASC20Market address ", asc20Market.address);

  console.log('completed.');

}

main();
