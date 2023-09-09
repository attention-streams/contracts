// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./interfaces/ITopic.sol";
import "./Choice.sol";

contract Topic is ITopic {
    uint256 public immutable startTime;
    uint256 public immutable cycleDuration;
    uint256 public immutable totalCycles;
    uint256 public immutable accrualRate;
    uint256 public immutable contributorFee;
    uint256 public immutable topicFee;
    address public immutable funds;

    address public immutable arena;

    address[] public choices;

    constructor(
        uint256 _startTime,
        uint256 _cycleDuration,
        uint256 _totalCycles,
        uint256 _accrualRate,
        uint256 _contributorFee,
        uint256 _topicFee,
        address _funds,
        address _arena
    ) {
        startTime = _startTime;
        cycleDuration = _cycleDuration;
        totalCycles = _totalCycles;
        accrualRate = _accrualRate;
        contributorFee = _contributorFee;
        topicFee = _topicFee;
        funds = _funds;
        arena = _arena;
    }

    function deployChoice() external {
        choices.push(address(new Choice(address(this))));
    }

    function choicesLength() public view returns (uint256) {
        return choices.length;
    }

    function currentCycleNumber() external view returns (uint256) {
        return (block.timestamp - startTime) / cycleDuration;
    }
}
