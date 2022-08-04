// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

struct Choice {
    string description;
    address payable funds; // fees are paid to this address
    uint16 feePercentage; // fees paid to choice from votes
    uint256 fundingTarget; // cannot receive funds more than this amount
}
