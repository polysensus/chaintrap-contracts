const hre = require("hardhat");

const FacetCutAction = { Add: 0, Replace: 1, Remove: 2 }

async function deployArena(signer) {
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
exports.deployArena = deployArena;