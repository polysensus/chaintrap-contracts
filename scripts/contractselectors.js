const ethers = require("ethers");
const path = require("path/posix");

const args = process.argv.slice(2);

if (args.length < 1) {
  console.log(`please supply the correct parameters:
    facetName ["paths,to,exclude" path-to-artifacts] 
  `);
  process.exit(1);
}

async function printSelectors(contractName, opts) {

  const artifactsPath = opts.artifactsPath ??  "../build/forge";
  const exclude = (opts.exclude ?? "").split(",");

  const contractFilePath = path.join(
    artifactsPath,
    `${contractName}.sol`,
    `${contractName}.json`
  );
  const contractArtifact = require(contractFilePath);
  const abi = contractArtifact.abi;
  const bytecode = contractArtifact.bytecode;
  const target = new ethers.ContractFactory(abi, bytecode);
  const targetSignatures = Object.keys(target.interface.functions);

  const selectors = [];

  for (const sig of targetSignatures) {
    for (const ex of exclude)
      if (ex === "" || sig.startsWith(ex)) {
        if (opts?.verbose > 0)
          process.stdout.write(`excluding: ${sig}, prefixed by:${ex}\n`);
        continue;
      }
    const sel = target.interface.getSighash(sig);
    selectors.push(sel);

    if (opts?.showsel !== true && opts?.showsigs !== true)
      continue;

    // showsigs implies showsel
    process.stdout.write(sel);
    if (opts?.showsigs === true)
      process.stdout.write(` ${sig}`);
    process.stdout.write("\n");
  }
  if (opts?.noencode === true) return;

  // By default, the abi is sorted by *signature*
  if (opts?.sort === true)
    selectors.sort();

  const coder = ethers.utils.defaultAbiCoder;
  const coded = coder.encode(["bytes4[]"], [selectors]);
  process.stdout.write(coded);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
let opts = {}

if (args.length > 1)
  opts = {...opts, ...JSON.parse(args[1])}

if (opts?.verbose > 0)
  process.stdout.write(`${JSON.stringify(opts)}\n`);

printSelectors(args[0], opts)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
