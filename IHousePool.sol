// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IHousePool
{
    event AddETHLiquidity(address indexed from, uint256 amount);

    event AddTokenLiquidity(address indexed from, address indexed token, uint256 amount);
    
    event RemoveETHLiquidity(address indexed to, uint256 amount);

    event RemoveTokenLiquidity(address indexed to, address indexed token, uint256 amount);

    function getTokenBalance(address token) external view returns (uint256);

    function addETHLiquidity() external payable returns (bool);

    function addTokenLiquidity(address token, uint256 amount) external returns (bool);

    function removeETHLiquidity(uint256 shareAmount) external returns (bool);

    function removeTokenLiquidity(address token, uint256 shareAmount) external returns (bool);

    function requestETHRoll(uint256[][3] memory rolls, bytes32 keyHash, uint64 subId, uint16 confirmations, uint32 gasLimit) external payable returns (uint256);

    function requestTokenRoll(address token, uint256 amount, uint256[][3] memory rolls, bytes32 keyHash, uint64 subId, uint16 confirmations, uint32 gasLimit) external returns (uint256);
}