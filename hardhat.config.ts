import "@nomicfoundation/hardhat-chai-matchers";
import "@nomicfoundation/hardhat-foundry";
import "@nomicfoundation/hardhat-toolbox";
import "@typechain/hardhat";
import "tsconfig-paths/register";

const MUMBAI_URL = process.env.MUMBAI_URL;

let extra_networks: HardhatUserConfig['networks'] = {};

if (MUMBAI_URL) {
  extra_networks = {
    ...extra_networks, 
    polygon_mumbai: {
      url: MUMBAI_URL,
      accounts: ['0xda36da69010b7baef829d14cf2dfd2caafba98a17aef538161741b2c1992a5a2']
    }
  };
}

const config: HardhatUserConfig = {
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
    version: "0.8.22",
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
    tests: "tests/hh",
    cache: "cache/hh",
    artifacts: "build/hh/artifacts"
  }
};

export default config;
