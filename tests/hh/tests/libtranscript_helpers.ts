import { ethers } from "hardhat";
// import hre from "hardhat";

export function conditionInput(value: any): string {
  return ethers.utils.hexlify(
    ethers.utils.zeroPad(ethers.utils.hexlify(value), 32)
  );
}

interface CreateGameParams {
  tokenURI?: string;
  registrationLimit?: number;
  trialistArgs: any; // Update with appropriate type
  roots: { [label: string]: string };
  choiceInputTypes: any[]; // Update with appropriate type
  transitionTypes: any[]; // Update with appropriate type
  victoryTransitionTypes: any[]; // Update with appropriate type
  haltParticipantTransitionTypes: any[]; // Update with appropriate type
  livesIncrement: any[]; // Update with appropriate type
  livesDecrement: any[]; // Update with appropriate type
}

export async function createGame(arena: any, params: CreateGameParams) {
  const rootLabels: string[] = [];
  const roots: string[] = [];
  const labeled: { [label: string]: { label32: string; root: string } } = {};

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
