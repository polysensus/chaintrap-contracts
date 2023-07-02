import hre from "hardhat";
const ethers = hre.ethers;

export async function createGame(arena, params) {
  const rootLabels = [];
  const roots = [];
  const labeled = {};

  for (const [label, root] of Object.entries(params.roots)) {
    const label32 = ethers.utils.formatBytes32String(label);
    rootLabels.push(label32);
    roots.push(root);
    labeled[label] = { label32, root };
  }
  let tx = await arena.createGame({
    tokenURI: params.tokenURI ?? "",
    registrationLimit: params.registrationLimit ?? 3,
    rootLabels,
    roots,
  });
  let r = await tx.wait();
  return { tx, r, rootLabels, roots, labeled };
}
