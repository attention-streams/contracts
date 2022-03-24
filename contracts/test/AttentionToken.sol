// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Attention is ERC20 {
    constructor() ERC20("Attention", "ATN") {
        _mint(msg.sender, 1000 * 10**decimals());
    }
}
