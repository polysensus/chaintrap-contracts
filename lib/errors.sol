// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;
/// IsInitialised is raised on attempts to initialise something a second time. If the type supports reset, use that instead.
error IsInitialised();

/// IDExuastion is raised when the desired id would overflow the type used to store it.
error IDExhaustion();
error IDOutOfRange();
