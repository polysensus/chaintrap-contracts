import hre from "hardhat";
import fs from "fs";
import {
  DiamondDeployer,
  FacetCutOpts,
  FileReader,
  Reporter,
} from "@polysensus/diamond-deploy";

function readJson(filename) {
  return JSON.parse(fs.readFileSync(filename, "utf-8"));
}

export async function deployArenaFixture() {
  const [deployer, owner] = await hre.ethers.getSigners();
  const proxy = await deployArena(deployer, owner, {});
  return [proxy, owner];
}

export async function deployArena(signer, owner, options = {}) {
  options.commit = true;
  options.diamondOwner = owner;
  options.diamondLoupeName = "DiamondLoupeFacet";
  options.diamondCutName = "DiamondCutFacet";
  options.diamondInitName = "DiamondNew";
  options.diamondInitArgs =
    '[{"typeURIs": ["GAME_TYPE", "TRANSCRIPT_TYPE", "FURNITURE_TYPE"]}]';

  const cuts = readJson(options.facets ?? ".local/dev/diamond-deploy.json").map(
    (o) => new FacetCutOpts(o)
  );

  const deployer = new DiamondDeployer(
    new Reporter(console.log, console.log, console.log),
    signer,
    { FileReader: new FileReader() },
    options
  );
  await deployer.processERC2535Cuts(cuts);
  await deployer.processCuts(cuts);
  if (!deployer.canDeploy())
    throw new Error(
      `can't deploy contracts, probably missing artifiacts or facets`
    );
  const result = await deployer.deploy();
  if (result.isErr()) throw new Error(result.errmsg());
  if (!result.address)
    throw new Error("no adddress on result for proxy deployment");

  return result.address;
}
