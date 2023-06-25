// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IHousePoolToken.sol";

contract HousePoolToken is ERC20, Ownable {
    uint256 immutable public MaxSupply;

    constructor(uint256 maxSupply) ERC20("HousePool", "HP") {
        MaxSupply = maxSupply;
    }

    function mint(address receiver, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= MaxSupply);
        _mint(receiver, amount);
    }
}