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

  return result.address;
}


async function deployArena2(signer) {
  if (!signer) {
    signer = (await hre.ethers.getSigners())[0];
  }

  const DiamondCutFacet = await hre.ethers.getContractFactory('DiamondCutFacet');
  const diamondCutFacet = await DiamondCutFacet.deploy();
  console.log(`deployed DiamondCutFacet@${diamondCutFacet.address}`);

  const Diamond = await hre.ethers.getContractFactory('Diamond');
  const diamond = await Diamond.deploy(signer.address, diamondCutFacet.address);
  console.log(`deployed Diamond@${diamond.address}`);

  const DiamondNew = await hre.ethers.getContractFactory('DiamondNew');
  const diamondNew = await DiamondNew.deploy();
  console.log(`deployed DiamondNew@${diamondNew.address}`);

  const exclusions = {
    ERC1155ArenaFacet: (contract) => getSelectors(contract).filter((sel) => sel != '0x01ffc9a7' )
  }

  const FacetNames = [
    'DiamondLoupeFacet',
    'OwnershipFacet',
    'ArenaCallsFacet',
    'ArenaFacet',
    'ArenaTranscriptsFacet',
    'ERC1155ArenaFacet'
  ]

  const cut = [];

  for (const FacetName of FacetNames) {
    const Facet = await hre.ethers.getContractFactory(FacetName);
    const facet = await Facet.deploy();
    console.log(`deployed facet: ${FacetName}@${facet.address}`);
    cut.push({
      facetAddress: facet.address,
      action: FacetCutAction.Add,
      functionSelectors: (exclusions[FacetName] ?? getSelectors)(facet)
    });
  }

  const diamondCut = await hre.ethers.getContractAt('IDiamondCut', diamond.address);
  let tx;
  let receipt;

  let functionCall = diamondNew.interface.encodeFunctionData(
    'init', [{typeURIs: ["GAME_TYPE", "TRANSCRIPT_TYPE", "FURNITURE_TYPE"]}]);

  tx = await diamondCut.diamondCut(cut, diamondNew.address, functionCall);
  console.log(`DiamondNew.init tx: ${tx.hash}`);
  receipt = await tx.wait();
  if (!receipt.status) {
    throw Error(`Diamond arena new deploy & cut failed: ${tx.hash}`);
  }
  console.log(`Completed arena diamond deploy @${diamond.address}`);

  const proxy = {
    address: diamond.address
  }
  for (const FacetName of FacetNames) {
    proxy[FacetName] = await hre.ethers.getContractAt(FacetName, diamond.address)
  }
  
  return proxy;
}

function getSelectors (contract) {
  const signatures = Object.keys(contract.interface.functions)
  const selectors = signatures.reduce((acc, val) => {
    if (val !== 'init(bytes)') {
      acc.push(contract.interface.getSighash(val))
    }
    return acc
  }, [])
  return selectors
}
exports.readJson = readJson;
exports.deployArena = deployArena;
exports.deployArenaFixture = deployArenaFixture;