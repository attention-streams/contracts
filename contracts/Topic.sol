// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./Choice.sol";

contract Topic {
    uint256 public immutable startTime;
    uint256 public immutable cycleDuration;
    uint256 public immutable totalCycles;
    uint256 public immutable accrualRate;

    address[] choices;

    constructor(
        uint256 _startTime,
        uint256 _cycleDuration,
        uint256 _totalCycles,
        uint256 _accrualRate
    ) {
        startTime = _startTime;
        cycleDuration = _cycleDuration;
        totalCycles = _totalCycles;
        accrualRate = _accrualRate;
    }

    function choicesLength() external view returns (uint256) {
        return choices.length;
    }

    function currentCycle() public view returns (uint256) {
        return (block.timestamp - startTime) / cycleDuration;
    }

    function deployChoice(uint256 _feeRate) external {
        choices.push(address(new Choice(address(this), _feeRate, accrualRate)));
    }
}
