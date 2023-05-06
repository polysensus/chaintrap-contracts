/**
 * @type import('hardhat/config').HardhatUserConfig
 */
require("@typechain/hardhat");
require("@nomicfoundation/hardhat-foundry");
require("@nomicfoundation/hardhat-chai-matchers");
require("@nomicfoundation/hardhat-toolbox");
require("hardhat-deploy");

MUMBAI_URL = process.env["MUMBAI_URL"]

let extra_networks = {}

if (MUMBAI_URL) {
  extra_networks = {...extra_networks, 
     polygon_mumbai: {
      url: MUMBAI_URL,
      accounts: ['0xda36da69010b7baef829d14cf2dfd2caafba98a17aef538161741b2c1992a5a2']
     }
  }
}

module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    ...extra_networks,
    // always enable hardhat
    hardhat: {
      allowUnlimitedContractSize: true,
      chainId: 31337,
      gas: "auto",
      gasPrice: 0,
      initialBaseFeePerGas: 0
    }
 },
 namedAccounts: {
   deployer: 10
 },
 solidity: {
    version: "0.8.9",
    settings: {
      // hh does not support re-mappings yet
      optimizer : {
       enabled: true,
       runs: 20
      }
    }
  },
  paths: {
    // using hardhat-foundry to get hh to work with foundry & get the benefit
    // of source remap this means using sources here is redundant.
    // sources: "chaintrap",
    tests: "./tests/hh/tests",
    cache: "./build/hh/cache",
    artifacts: "build/hh/artifacts"
  },
};
