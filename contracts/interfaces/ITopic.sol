// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface ITopic {
    function startTime() external view;

    function cycleDuration() external view;

    function totalCycles() external view;

    function currentCycle() external view returns (uint256);
}
