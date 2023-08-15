// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface ITopic {
    function startTime() external view returns (uint256);

    function cycleDuration() external view returns (uint256);

    function totalCycles() external view returns (uint256);

    function accrualRate() external view returns (uint256);

    function choiceFeeRate() external view returns (uint256);

    function currentCycle() external view returns (uint256);
}
