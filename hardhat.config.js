/**
 * @type import('hardhat/config').HardhatUserConfig
 */
 require("@nomiclabs/hardhat-waffle");
 require("hardhat-deploy");

 module.exports = {
   defaultNetwork: "hardhat",
   networks: {
     hardhat: {
      chainId: 6267 // iona/rrr
    }
  },
  namedAccounts: {
    deployer: 0,
  },
  solidity: {
     version: "0.8.9",
     settings: {
       // hh does not support re-mappings yet
     }
   },
   paths: {
     sources: "./chaintrap",
     tests: "./hh-tests",
     cache: "./build/hh/cache",
     artifacts: "build/hh/artifacts"
   }
 };