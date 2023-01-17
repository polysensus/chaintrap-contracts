/**
 * @type import('hardhat/config').HardhatUserConfig
 */
 require("@nomiclabs/hardhat-waffle");
 require("hardhat-deploy");

 module.exports = {
   // defaultNetwork: "polygon_mumbai",
   defaultNetwork: "hardhat",
   networks: {
     polygon_mumbai: {
      url: 'https://polygon-mainnet.g.alchemy.com/v2/MGrFH1fAmoFeCc24hxR_vFd9dTmN0DBR',
      accounts: ['0xda36da69010b7baef829d14cf2dfd2caafba98a17aef538161741b2c1992a5a2']
     },
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
     deploy: "./tests/hh/deploy",
     deployments: "./tests/hh/deployments",
     sources: "./chaintrap",
     tests: "./tests/hh/tests",
     cache: "./build/hh/cache",
     artifacts: "build/hh/artifacts"
   }
 };
