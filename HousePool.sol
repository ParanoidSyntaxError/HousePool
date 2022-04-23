// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./VRFHelper.sol";
import "../Shared/IERC20.sol";

//TODO: HousePool interface

contract HousePool is VRFHelper
{
    event AddLiquidity(address indexed from, address indexed token, uint256 amount);
    event RemoveLiquidity(address indexed to, address indexed token, uint256 amount);

    mapping(address => IERC20) private _erc20Tokens;
    mapping(address => mapping(address => uint256)) private _shares;
    mapping(address => uint256) private _shareTotals;

    constructor()
    {

    }

    function getLiquidityBalance(address token) external view returns (uint256)
    {
        return _erc20Tokens[token].balanceOf(address(this));
    }

    function createPool(address token) public returns (bool)
    {
        _erc20Tokens[token] = IERC20(token);

        return true;
    }

    function addLiquidity(address token, uint256 amount) external returns (bool)
    {
        if(_erc20Tokens[token] == IERC20(address(0)))
        {
            createPool(token);
        }

        _erc20Tokens[token].transferFrom(msg.sender, address(this), amount);

        _shares[token][msg.sender] += amount;
        _shareTotals[token] += amount;

        emit AddLiquidity(msg.sender, token, amount);

        return true;
    }

    function removeLiquidity(address token, uint256 shareAmount) external returns (bool)
    {
        require(shareAmount <= _shares[token][msg.sender]);

        uint256 contractBalance = _erc20Tokens[token].balanceOf(address(this));

        uint256 amount = contractBalance / (_shareTotals[token] / shareAmount); 

        _shares[token][msg.sender] -= shareAmount;
        _shareTotals[token] -= shareAmount;

        _erc20Tokens[token].transfer(msg.sender, amount);

        emit RemoveLiquidity(msg.sender, token, amount);

        return true;
    }

    //rolls[index][bet, win, odds]
    function requestLiquidityRoll(uint256[][3] memory rolls, address token, bytes32 keyHash, uint64 subscriptionId, uint16 requestConfirmations, uint32 callbackGasLimit, uint32 wordCount) external returns (uint256)
    {
        require(rolls.length == wordCount);

        uint256 contractBalance = _erc20Tokens[token].balanceOf(address(this));

        for(uint256 i = 0; i < rolls.length; i++)
        {
            //Check roll amount no greater than .01% of liquidity
            if(rolls[i][0] > contractBalance / 10000)
            {
                revert();
            }

            //TODO: Check math (careful of rounding)
            //TODO: House edge should be at least 1%
            //Check odds have > 0% house edge
            uint256 payout = 100 / rolls[i][2];
            uint256 expectedReturn = rolls[i][0] * payout;
            if(rolls[i][1] >= expectedReturn)
            {
                revert();
            }    
        }

        return requestRandomWords(msg.sender, keyHash, subscriptionId, requestConfirmations, callbackGasLimit, wordCount);
    }
}// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./VRFHelper.sol";
import "../Shared/IERC20.sol";

//TODO: HousePool interface

contract HousePool is VRFHelper
{
    event AddLiquidity(address indexed from, address indexed token, uint256 amount);
    event RemoveLiquidity(address indexed to, address indexed token, uint256 amount);

    mapping(address => IERC20) private _erc20Tokens;
    mapping(address => mapping(address => uint256)) private _shares;
    mapping(address => uint256) private _shareTotals;

    constructor()
    {

    }

    function getLiquidityBalance(address token) external view returns (uint256)
    {
        return _erc20Tokens[token].balanceOf(address(this));
    }

    function createPool(address token) public returns (bool)
    {
        _erc20Tokens[token] = IERC20(token);

        return true;
    }

    function addLiquidity(address token, uint256 amount) external returns (bool)
    {
        if(_erc20Tokens[token] == IERC20(address(0)))
        {
            createPool(token);
        }

        _erc20Tokens[token].transferFrom(msg.sender, address(this), amount);

        _shares[token][msg.sender] += amount;
        _shareTotals[token] += amount;

        emit AddLiquidity(msg.sender, token, amount);

        return true;
    }

    function removeLiquidity(address token, uint256 shareAmount) external returns (bool)
    {
        require(shareAmount <= _shares[token][msg.sender]);

        uint256 contractBalance = _erc20Tokens[token].balanceOf(address(this));

        uint256 amount = contractBalance / (_shareTotals[token] / shareAmount); 

        _shares[token][msg.sender] -= shareAmount;
        _shareTotals[token] -= shareAmount;

        _erc20Tokens[token].transfer(msg.sender, amount);

        emit RemoveLiquidity(msg.sender, token, amount);

        return true;
    }

    //rolls[index][bet, win, odds]
    function requestLiquidityRoll(uint256[][3] memory rolls, address token, bytes32 keyHash, uint64 subscriptionId, uint16 requestConfirmations, uint32 callbackGasLimit, uint32 wordCount) external returns (uint256)
    {
        require(rolls.length == wordCount);

        uint256 contractBalance = _erc20Tokens[token].balanceOf(address(this));

        for(uint256 i = 0; i < rolls.length; i++)
        {
            //Check roll amount no greater than .01% of liquidity
            if(rolls[i][0] > contractBalance / 10000)
            {
                revert();
            }

            //TODO: Check math (careful of rounding)
            //TODO: House edge should be at least 1%
            //Check odds have > 0% house edge
            uint256 payout = 100 / rolls[i][2];
            uint256 expectedReturn = rolls[i][0] * payout;
            if(rolls[i][1] >= expectedReturn)
            {
                revert();
            }    
        }

        return requestRandomWords(msg.sender, keyHash, subscriptionId, requestConfirmations, callbackGasLimit, wordCount);
    }
}