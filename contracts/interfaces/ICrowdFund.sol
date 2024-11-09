// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ICrowdFund {

    /// Define how many decimal points of precision to use for percentages.
    /// The value supplied is defined to equal 100% for values using percentages.
    /// So, if `PERCENT_SCALE` = 1000000 then 1000000 would represent 100% and 253412 would represent 25.3412%
    function percentScale() public view returns (uint256);

    /// @dev The duration of a cycle for Ideas and Solutions in seconds.
    function cycleLength() public view returns (uint256);

    /// @dev The rate at which shares of Ideas and Solutions increase every cycle. Uses `PERCENT_SCALE` for precision.
    function accrualRate() public view returns (uint256);

    function feeToken() public view returns (IERC20);

    /// The percentage used to calculate the feed paid for creating or contributing to an Idea.
    /// The fee paid is the greater of `percentFee` times the amount contributed and `minFee`.
    /// Uses `PERCENT_SCALE` to represent a percentage value.
    function percentFee() public view returns (uint256);

    /// `minFee` is the minimum fee (in `feeToken`) paid for creating or contributing to an idea,
    /// and the only fee paid for creating solutions and updating profiles.
    function minFee() public view returns (uint256);
}
