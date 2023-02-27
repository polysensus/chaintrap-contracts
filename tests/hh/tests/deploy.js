const hre = require("hardhat");
const fs = require("fs");
const dd = require("@polysensus/diamond-deploy");
const { DiamondDeployer, FacetCutOpts, FileReader, Reporter } = dd;
// import hre from "hardhat";
// import { DiamondDeployer, FacetCutOpts, FileReader } from "@polysensus/diamond-deploy";

function readJson(filename) {
  return JSON.parse(fs.readFileSync(filename, "utf-8"));
}

async function deployArenaFixture() {
  const [deployer, owner] = await hre.ethers.getSigners();
  const proxy = await deployArena(deployer, owner, {});
  return [proxy, owner];
}

async function deployArena(signer, owner, options={}) {

  options.diamondOwner = owner;
  options.diamondLoupeName = "DiamondLoupeFacet";
  options.diamondCutName = "DiamondCutFacet";
  options.diamondInitName = "DiamondNew";
  options.diamondInitArgs = "[{\"typeURIs\": [\"GAME_TYPE\", \"TRANSCRIPT_TYPE\", \"FURNITURE_TYPE\"]}]";


  const cuts = readJson(options.facets ?? ".local/dev/diamond-deploy.json").map(
    (o) => new FacetCutOpts(o)
  );

  const deployer = new DiamondDeployer(
    new Reporter(console.log, console.log, console.log), signer, {FileReader: new FileReader()}, options);
  await deployer.processERC2535Cuts(cuts);
  await deployer.processCuts(cuts);
  if (!deployer.canDeploy())
    throw new Error(`can't deploy contracts, probably missing artifiacts or facets`);
  const result = await deployer.deploy();
  if (result.isErr())
    throw new Error(result.errmsg())
  if (!result.address)
    throw new Error("no adddress on result for proxy deployment");


  return result.address;
}

exports.readJson = readJson;
exports.deployArena = deployArena;
exports.deployArenaFixture = deployArenaFixture;