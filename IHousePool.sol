// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IHousePool
{
    event AddETHLiquidity(address indexed from, uint256 amount);

    event AddTokenLiquidity(address indexed from, address indexed token, uint256 amount);
    
    event RemoveETHLiquidity(address indexed to, uint256 amount);

    event RemoveTokenLiquidity(address indexed to, address indexed token, uint256 amount);

    event RequestETHRoll(address indexed from, uint256 amount);

    event RequestTokenRoll(address indexed from, address indexed token, uint256 amount);

    event WithdrawETH(address indexed to, uint256 amount);

    event WithdrawToken(address indexed to, address indexed token, uint256 amount);

    function getRoll(uint256) external view returns(address, address, uint256[] memory, uint256[5][][] memory);

    function getETHIndex() external view returns (address);

    function isWinningBet(uint256 requestId, uint256 responseIndex, uint256 overlapIndex) external view returns (bool);

    function addETHLiquidity() external payable returns (bool);

    function addTokenLiquidity(address token, uint256 amount) external returns (bool);

    function removeETHLiquidity(uint256 shareAmount) external returns (bool);

    function removeTokenLiquidity(address token, uint256 shareAmount) external returns (bool);

    function requestETHRoll(uint256[5][][] memory bets, bytes32 keyHash, uint64 subId, uint16 confirmations, uint32 gasLimit) external payable returns (uint256);

    function requestTokenRoll(address token, uint256[5][][] memory bets, bytes32 keyHash, uint64 subId, uint16 confirmations, uint32 gasLimit) external returns (uint256);

    function withdrawRoll(uint256 requestID) external returns (uint256);
}