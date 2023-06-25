// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./interfaces/IHousePoolToken.sol";

contract HousePoolToken is ERC20 {
    constructor() ERC20("HousePool", "HP") {
        
    }

    function mint(address receiver, uint256 amount) external {
        _mint(receiver, amount);
    }
}