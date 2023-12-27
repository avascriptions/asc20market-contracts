import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import '@openzeppelin/hardhat-upgrades';
import { ethers } from 'ethers';

// this is an empty account: 0x785B2C99aac3506791F6825026a60d78dA1aB5D7 
const PRIVATE_KEY = 'ca35c6c7f7c0e1aee8807f22d6a2d7052b9017c98c93f1b7d813ec03f71de7a6'

const config: HardhatUserConfig = {
  mocha: {
    timeout: 100000000
  },
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      accounts: [ { privateKey: PRIVATE_KEY, balance: ethers.utils.parseEther('10').toString() } ]
    },
    avax: {
      chainId: 43114,
      url: 'https://api.avax.network/ext/bc/C/rpc	',
      gasPrice: 100 * 1000000000,
      accounts: [ PRIVATE_KEY ]
    },
    fuji: {
      chainId: 43113,
      url: 'https://api.avax-test.network/ext/bc/C/rpc',
      accounts: [ PRIVATE_KEY ]
    },
  },
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 800,
      },
    },
  },
};

export default config;
