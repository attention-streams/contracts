// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IChoice {
    function tokens() external view returns (uint256);

    function totalSharesAtCycle(uint256 cycleNumber) external view returns (uint256);

    function contributeFor(uint256 amount, address receiver) external returns (uint256 positionIndex);
}
