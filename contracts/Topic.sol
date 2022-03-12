// SPDX-License-Identifier:
pragma solidity ^0.8.0;

import "./Arena.sol";

contract Topic {
    Arena public arena;
    constructor (address arenaAddress) {
        arena = Arena(arenaAddress);
    }
}
