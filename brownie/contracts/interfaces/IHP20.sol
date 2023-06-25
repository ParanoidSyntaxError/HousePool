// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IHP20 {
    function initialize(address housePool, string memory initName, string memory initSymbol, uint8 initDecimals) external;
    function mint(address receiver, uint256 amount) external;
    function clearBalances() external;

    function burn(uint256 amount) external;
    function burnFrom(address account, uint256 amount) external;
}