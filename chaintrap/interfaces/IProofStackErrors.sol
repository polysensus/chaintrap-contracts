// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

error ProofStack_InputRefToShort();
error ProofStack_ProoRefInvalid();
error ProofStack_MustStartWithChoiceSet();
error ProofStack_MustConcludeWithTransition();
error ProofStack_MustBeDerivedFromChoiceSet();
error ProofStack_MustDeriveFromBothChoiceSet();
error ProofStack_ReferenceFloorBreach();
error ProofStack_TooManyChoiceSets();
error ProofStack_TransitionProofIncomplete();
