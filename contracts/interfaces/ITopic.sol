// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface ITopic {
    function startTime() external view returns (uint256);

    function cycleDuration() external view returns (uint256);

    function totalCycles() external view returns (uint256);

    function accrualRate() external view returns (uint256);

    /// @notice The contributor fee % for all choices in this topic. Uses 4 digits of precision; e.g. 10.25% = 1025.
    /// This is the fee that goes to previous contributors.
    function contributorFee() external view returns (uint256);

    function currentCycleNumber() external view returns (uint256);

    function token() external view returns (address);
}
