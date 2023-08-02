// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract Topic {
    uint256 public immutable startTime;
    uint256 public immutable cycleDuration;
    uint256 public immutable totalCycles;

    constructor(
        uint256 _startTime,
        uint256 _cycleDuration,
        uint256 _totalCycles
    ) {
        startTime = _startTime;
        cycleDuration = _cycleDuration;
        totalCycles = _totalCycles;
    }

    function currentCycle() public view returns (uint256) {
        return (block.timestamp - startTime) / cycleDuration;
    }
}
