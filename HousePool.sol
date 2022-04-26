// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IHousePool.sol";
import "./VRFHelper.sol";
import "../Shared/IERC20.sol";

// DONE: HousePool interface
// DONE: Get address earnings
// DONE: Get address liquidity provided
// DONE: Withdraw winning bets
// DONE: House edge must be at least 1%
// DONE: Overlapping bets

// TODO: Allow two decimal places in house math
// TODO: Audit house math
// TODO: Comments
// TODO: Docs

contract HousePool is IHousePool, VRFHelper
{
    mapping(address => mapping(address => uint256)) private _shares;
    mapping(address => uint256) private _shareTotals;

    /*
        @dev address zero used for ETH shares index
    */
    address private constant ETH_INDEX = address(0);

    mapping(address => uint256) private _unclaimedPayouts;

    constructor()
    {

    }

    /*
        @return principle is the inital amount of ETH provided
        @return earnings are the amount of ETH earned
    */
    function getETHShares(address account) external view returns (uint256 principle, uint256 earnings)
    {
        return (_shares[ETH_INDEX][account], (_shareTotals[ETH_INDEX] / _shares[ETH_INDEX][account]) - _shares[ETH_INDEX][account]);
    }

    /*
        @return principle is the inital amount of tokens provided
        @return earnings are the amount of tokens earned
    */
    function getTokenShares(address account, address token) external view returns (uint256 principle, uint256 earnings) 
    {
        return (_shares[token][account], (_shareTotals[token] / _shares[token][account]) - _shares[token][account]);
    }

    /*
        @param contract address of ERC20 token

        @return ERC20 token balance of this contract
    */
    function getTokenBalance(address token) external override view returns (uint256)
    {
        return _getLiquidityBalance(token);
    }

    /*
        @return success
    */
    function addETHLiquidity() external override payable returns (bool)
    {
        _addLiquidity(msg.sender, ETH_INDEX, msg.value);

        return true;
    }

    /*
        @notice contract must be approved to spend at least amount specified in parameters

        @param contract address of ERC20 token to add
        @param amount of ERC20 tokens to add to the liquidity

        @return success
    */
    function addTokenLiquidity(address token, uint256 amount) external override returns (bool)
    {
        _addLiquidity(msg.sender, token, amount);

        return true;
    }

    /*
        @notice to remove your principle and earnings, enter the principle

        @param number of shares to withdraw from liquidity

        @return success
    */
    function removeETHLiquidity(uint256 shareAmount) external override returns (bool)
    {
        _removeLiquidity(msg.sender, ETH_INDEX, shareAmount);

        return true;    
    }

    /*
        @notice to remove your principle and earnings, enter the principle

        @param contract address of ERC20 token to remove
        @param number of shares to withdraw from liquidity

        @return success
    */
    function removeTokenLiquidity(address token, uint256 shareAmount) external override returns (bool)
    {
        _removeLiquidity(msg.sender, token, shareAmount);

        return true;
    }

    /*
        @notice https://docs.chain.link/docs/chainlink-vrf/

        @param bets
        @param keyHash corresponds to a particular oracle job which uses that key for generating the VRF proof
        @param subId is the ID of the VRF subscription. Must be funded with the minimum subscription balance required for the selected keyHash
        @param confirmations is how many blocks you'd like the oracle to wait before responding to the request
        @param gasLimit is how much gas you'd like to receive in your fulfillRandomWords callback

        @return request ID, a unique identifier of the request
    */
    function requestETHRoll(uint256[][][3] memory bets, bytes32 keyHash, uint64 subId, uint16 confirmations, uint32 gasLimit) external override payable returns (uint256)
    {
        return _requestRoll(msg.sender, ETH_INDEX, msg.value, bets, keyHash, subId, confirmations, gasLimit);
    }

    /*
        @notice https://docs.chain.link/docs/chainlink-vrf/

        @param token
        @param amount
        @param bets
        @param keyHash corresponds to a particular oracle job which uses that key for generating the VRF proof
        @param subId is the ID of the VRF subscription. Must be funded with the minimum subscription balance required for the selected keyHash
        @param confirmations is how many blocks you'd like the oracle to wait before responding to the request
        @param gasLimit is how much gas you'd like to receive in your fulfillRandomWords callback

        @return request ID, a unique identifier of the request
    */
    function requestTokenRoll(address token, uint256[][][3] memory bets, bytes32 keyHash, uint64 subId, uint16 confirmations, uint32 gasLimit) external override returns (uint256)
    {
        return _requestRoll(msg.sender, token, 0, bets, keyHash, subId, confirmations, gasLimit);
    }

    function _getLiquidityBalance(address token) private view returns (uint256)
    {
        if(token == ETH_INDEX)
        {
            return address(this).balance;
        }

        return IERC20(token).balanceOf(address(this));
    }

    function _addLiquidity(address from, address token, uint256 amount) private
    {
        _shares[token][from] += amount;
        _shareTotals[token] += amount;

        if(token != ETH_INDEX)
        {
            IERC20(token).transferFrom(from, address(this), amount);

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

        uint256 contractBalance = _getLiquidityBalance(token);

        uint256 amount = contractBalance / (_shareTotals[token] / shareAmount); 

        _shares[token][from] -= shareAmount;
        _shareTotals[token] -= shareAmount;

        if(token == ETH_INDEX)
        {
            (bool os,) = payable(from).call{value: amount}("");
            require(os);

            emit RemoveETHLiquidity(from, amount);
        }
        else
        {
            IERC20(token).transfer(from, amount);

            emit RemoveTokenLiquidity(from, token, amount);
        }
    }

    //rolls[index][bet, win, odds]
    function _requestRoll(address from, address token, uint256 amount, uint256[][][3] memory bets, bytes32 keyHash, uint64 subId, uint16 confirmations, uint32 gasLimit) private returns (uint256)
    {
        uint256 totalBet = 0;

        uint256 contractBalance = _getLiquidityBalance(token);

        for(uint256 i = 0; i < bets.length; i++)
        {
            for(uint256 a = 0; a < bets[i].length; a++)
            {
                // Check roll amount no greater than .01% of liquidity
                require(bets[i][a][0] <= contractBalance / 10000);

                totalBet += bets[i][a][0];

                uint256 expectedReturn = bets[i][a][0] * (100 / bets[i][a][2]);
                require(bets[i][a][1] <= expectedReturn + (bets[i][a][1] / 100));   
            }
        }

        if(token != ETH_INDEX)
        {
            IERC20(token).transfer(from, totalBet);
        }
        else
        {
            require(amount >= totalBet);
        }

        return requestRandomWords(from, bets, token, keyHash, subId, confirmations, gasLimit);
    }

    function _withdrawRoll(uint256 requestId) private
    {
        require(rolls[requestId].owner != address(0));

        address owner = rolls[requestId].owner;
        rolls[requestId].owner = address(0);

        uint256 totalPayout = 0;

        for(uint256 i = 0; i < rolls[requestId].responses.length; i++)
        {
            uint256 rolledNumber = (rolls[requestId].responses[i] % 100) + 1;

            for(uint256 a = 0; a < rolls[requestId].bets[i].length; a++)
            {
                if(rolledNumber <= rolls[requestId].bets[i][a][2])
                {
                    totalPayout += rolls[requestId].bets[i][a][1];
                }
            }
        }

        if(rolls[requestId].token == ETH_INDEX)
        {
            (bool os,) = payable(owner).call{value: totalPayout}("");
            require(os);
        }
        else
        {
            IERC20(rolls[requestId].token).transfer(owner, totalPayout);
        }
    }
}