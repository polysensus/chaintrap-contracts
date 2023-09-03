import hre from "hardhat";
const ethers = hre.ethers;

export function conditionInput(value) {
  return ethers.utils.hexlify(
    ethers.utils.zeroPad(ethers.utils.hexlify(value), 32)
  );
}

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
    trialistArgs: params.trialistArgs,
    rootLabels,
    roots,
    choiceInputTypes: params.choiceInputTypes.map(conditionInput),
    transitionTypes: params.transitionTypes.map(conditionInput),
    victoryTransitionTypes: params.victoryTransitionTypes.map(conditionInput),
    haltParticipantTransitionTypes:
      params.haltParticipantTransitionTypes.map(conditionInput),
    livesIncrement: params.livesIncrement.map(conditionInput),
    livesDecrement: params.livesDecrement.map(conditionInput),
  });
  let r = await tx.wait();
  return { tx, r, rootLabels, roots, labeled };
}
