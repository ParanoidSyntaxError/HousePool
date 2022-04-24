// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./VRFHelper.sol";
import "../Shared/IERC20.sol";

//TODO: HousePool interface

contract HousePool is VRFHelper
{
    event AddETHLiquidity(address indexed from, uint256 amount);
    event AddTokenLiquidity(address indexed from, address indexed token, uint256 amount);
    event RemoveETHLiquidity(address indexed to, uint256 amount);
    event RemoveTokenLiquidity(address indexed to, address indexed token, uint256 amount);

    mapping(address => IERC20) private _erc20Tokens;
    mapping(address => mapping(address => uint256)) private _shares;
    mapping(address => uint256) private _shareTotals;

    address private constant BNB_INDEX = address(0);

    constructor()
    {

    }

    function getLiquidityBalance(address token) public view returns (uint256)
    {
        if(token == BNB_INDEX)
        {
            return address(this).balance;
        }

        return _erc20Tokens[token].balanceOf(address(this));
    }

    function createPool(address token) public returns (bool)
    {
        _erc20Tokens[token] = IERC20(token);

        return true;
    }

    function addETHLiquidity() external payable returns (bool)
    {
        _addLiquidity(msg.sender, BNB_INDEX, msg.value);

        return true;
    }

    function addTokenLiquidity(address token, uint256 amount) external returns (bool)
    {
        _addLiquidity(msg.sender, token, amount);

        return true;
    }

    function removeETHLiquidity(uint256 shareAmount) external returns (bool)
    {
        _removeLiquidity(msg.sender, BNB_INDEX, shareAmount);

        return true;    
    }

    function removeTokenLiquidity(address token, uint256 shareAmount) external returns (bool)
    {
        _removeLiquidity(msg.sender, token, shareAmount);

        return true;
    }

    function requestETHLiquidityRoll
    (
        uint256[][3] memory rolls, 
        bytes32 keyHash, 
        uint64 subscriptionId, 
        uint16 requestConfirmations, 
        uint32 callbackGasLimit, 
        uint32 wordCount
    ) external payable returns (uint256)
    {
        return _requestLiquidityRoll(msg.sender, BNB_INDEX, msg.value, rolls, keyHash, subscriptionId, requestConfirmations, callbackGasLimit, wordCount);
    }

    function requestTokenLiquidityRoll
    (
        address token, 
        uint256 amount,
        uint256[][3] memory rolls, 
        bytes32 keyHash, 
        uint64 subscriptionId, 
        uint16 requestConfirmations, 
        uint32 callbackGasLimit, 
        uint32 wordCount
    ) external returns (uint256)
    {
        return _requestLiquidityRoll(msg.sender, token, amount, rolls, keyHash, subscriptionId, requestConfirmations, callbackGasLimit, wordCount);
    }

    function _addLiquidity(address from, address token, uint256 amount) private
    {
        _shares[token][from] += amount;
        _shareTotals[token] += amount;

        if(token != BNB_INDEX)
        {
            if(_erc20Tokens[token] == IERC20(address(0)))
            {
                createPool(token);
            }

            _erc20Tokens[token].transferFrom(from, address(this), amount);

            emit AddTokenLiquidity(from, token, amount);
        }
        else
        {
            emit AddETHLiquidity(from, amount);
        }
    }

    function _removeLiquidity(address from, address token, uint256 shareAmount) private
    {
        require(shareAmount <= _shares[token][from]);

        uint256 contractBalance = getLiquidityBalance(token);

        uint256 amount = contractBalance / (_shareTotals[token] / shareAmount); 

        _shares[token][from] -= shareAmount;
        _shareTotals[token] -= shareAmount;

        if(token == BNB_INDEX)
        {
            (bool os,) = payable(from).call{value: amount}("");
            require(os);

            emit RemoveETHLiquidity(from, amount);
        }
        else
        {
            _erc20Tokens[token].transfer(from, amount);

            emit RemoveTokenLiquidity(from, token, amount);
        }
    }

    //rolls[index][bet, win, odds]
    function _requestLiquidityRoll
    (
        address from, 
        address token, 
        uint256 amount, 
        uint256[][3] memory rolls, 
        bytes32 keyHash, 
        uint64 subscriptionId, 
        uint16 requestConfirmations, 
        uint32 callbackGasLimit, 
        uint32 wordCount
    ) private returns (uint256)
    {
        require(rolls.length == wordCount);

        uint256 rollsBetAmount = 0;

        uint256 contractBalance = getLiquidityBalance(token);

        for(uint256 i = 0; i < rolls.length; i++)
        {
            rollsBetAmount += rolls[i][0];

            //Check roll amount no greater than .01% of liquidity
            require(rolls[i][0] <= contractBalance / 10000);

            //TODO: Check math (careful of rounding)
            //TODO: House edge should be at least 1%
            //Check odds have > 0% house edge
            uint256 payout = 100 / rolls[i][2];
            uint256 expectedReturn = rolls[i][0] * payout;
            require(rolls[i][1] < expectedReturn);   
        }

        require(rollsBetAmount >= amount);

        if(token != BNB_INDEX)
        {
            _erc20Tokens[token].transfer(from, amount);
        }

        return requestRandomWords(from, keyHash, subscriptionId, requestConfirmations, callbackGasLimit, wordCount);
    }
}