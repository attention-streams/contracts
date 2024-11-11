// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract Updraft is ERC20, ERC20Permit {
    constructor() ERC20("Updraft", "UPD") ERC20Permit("Updraft") {
        _mint(msg.sender, 100000000000 * 10 ** decimals());
    }
}
