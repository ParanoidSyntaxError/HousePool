// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract HousePoolToken is ERC20, ERC20Burnable {
    constructor() ERC20("HousePool Token", "HP") {
        _mint(msg.sender, 1000000000 * 10 ** decimals());
    }
}