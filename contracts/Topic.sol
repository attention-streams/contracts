// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./Choice.sol";

contract Topic {
    uint256 public immutable startTime;
    uint256 public immutable cycleDuration;
    uint256 public immutable totalCycles;
    uint256 public immutable accrualRate;
    uint256 public immutable choiceFeeRate;

    address[] public choices;

    constructor(
        uint256 _startTime,
        uint256 _cycleDuration,
        uint256 _totalCycles,
        uint256 _accrualRate,
        uint256 _choiceFeeRate
    ) {
        startTime = _startTime;
        cycleDuration = _cycleDuration;
        totalCycles = _totalCycles;
        accrualRate = _accrualRate;
        choiceFeeRate = _choiceFeeRate;
    }

    function choicesLength() external view returns (uint256) {
        return choices.length;
    }

    function currentCycle() public view returns (uint256) {
        return (block.timestamp - startTime) / cycleDuration;
    }

    function deployChoice() external {
        choices.push(address(new Choice(address(this))));
    }
}
