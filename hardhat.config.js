/**
 * @type import('hardhat/config').HardhatUserConfig
 */
 require("@nomiclabs/hardhat-waffle");
 require("hardhat-deploy");

 module.exports = {
   defaultNetwork: "hardhat",
   networks: {
     hardhat: {
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
