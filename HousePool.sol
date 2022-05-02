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
// DONE: Prevent withdraw of unclaimed payments

// TODO: Audit house math
// TODO: Comments
// TODO: Docs

contract HousePool is IHousePool, VRFHelper
{
    mapping(address => mapping(address => uint256)) public _shares;
    mapping(address => uint256) public _shareTotals;

    /*
        @dev address zero used for ETH indexes
    */

    constructor()
    {

    }

    receive() external payable {}

    /*  
        @param VRF request ID

        @return requestor address
        @return bet token
        @return VRF responses
        @return bets [VRF response][Overlap bet][Wager, PayoutOdds, Lower, Upper, Range]
    */
    function getRoll(uint256 requestId) external view override returns(address, address, uint256[] memory, uint256[5][][] memory)
    {
        return (vrfRequestors[requestId], vrfTokens[requestId], vrfResponses[requestId], vrfBets[requestId]);
    }

    /*
        @param address of share owner

        @return the inital amount of ETH provided
        @return amount of ETH that can be withdrawn
    */
    function getETHShares(address account) external view returns (uint256, uint256)
    {
        return (_shares[address(0)][account], address(this).balance / (_shareTotals[address(0)] / _shares[address(0)][account]));
    }

    /*
        @param address of share owner
        @param token address of shares

        @return the inital amount of tokens provided
        @return amount of tokens that can be withdrawn
    */
    function getTokenShares(address account, address token) external view returns (uint256, uint256) 
    {
        return (_shares[token][account], _getLiquidityBalance(token) / (_shareTotals[token] / _shares[token][account]));
    }

    /*
        @dev ERC20 tokens and ETH share the same mappings, use this address for ETH values

        @return address index used for ETH
    */
    function getETHIndex() external pure override returns (address)
    {
        return address(0);
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
        @param VRF request ID
        @param VRF response index
        @param overlap bet index

        @return did the bet win
    */
    function isWinningBet(uint256 requestId, uint256 responseIndex, uint256 overlapIndex) external view override returns (bool)
    {
        return _isWinningBet(requestId, responseIndex, overlapIndex);
    }

    /*
        @return success
    */
    function addETHLiquidity() external override payable returns (bool)
    {
        _addLiquidity(msg.sender, address(0), msg.value);

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
        require(token != address(0));

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
        _removeLiquidity(msg.sender, address(0), shareAmount);

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

        @param bets [VRF response][Overlap bet][Wager, PayoutOdds, Lower, Upper, Range]
        @param keyHash corresponds to a particular oracle job which uses that key for generating the VRF proof
        @param subId is the ID of the VRF subscription. Must be funded with the minimum subscription balance required for the selected keyHash
        @param confirmations is how many blocks you'd like the oracle to wait before responding to the request
        @param gasLimit is how much gas you'd like to receive in your fulfillRandomWords callback

        @return request ID, a unique identifier of the request
    */
    function requestETHRoll(uint256[5][][] memory bets, bytes32 keyHash, uint64 subId, uint16 confirmations, uint32 gasLimit) external override payable returns (uint256)
    {
        return _requestRoll(msg.sender, address(0), msg.value, bets, keyHash, subId, confirmations, gasLimit);
    }

    /*
        @notice contract must be approved to spend at least amount specified in parameters
        @notice PayoutOdds is formatted like a 2 point floating number. For example, 3500 is equal to 35.00f or 35x, and 50 would be the equivalent of 0.50f or 0.5x
        @notice https://docs.chain.link/docs/chainlink-vrf/

        @param contract address of token wagered
        @param bets [VRF response][Overlap bet][Wager, PayoutOdds, Lower, Upper, Range]
        @param keyHash corresponds to a particular oracle job which uses that key for generating the VRF proof
        @param subId is the ID of the VRF subscription. Must be funded with the minimum subscription balance required for the selected keyHash
        @param confirmations is how many blocks you'd like the oracle to wait before responding to the request
        @param gasLimit is how much gas you'd like to receive in your fulfillRandomWords callback

        @return VRF request ID
    */
    function requestTokenRoll(address token, uint256[5][][] memory bets, bytes32 keyHash, uint64 subId, uint16 confirmations, uint32 gasLimit) external override returns (uint256)
    {
        return _requestRoll(msg.sender, token, 0, bets, keyHash, subId, confirmations, gasLimit);
    }

    /*
        @notice transfers winning bets to the roll owner address

        @param VRF request ID
    */
    function withdrawRoll(uint256 requestID) external override
    {
        _withdrawRoll(requestID);
    }

    /*
        @param VRF request ID
        @param response index
        @param overlap index

        @return did bet win
    */
    function _isWinningBet(uint256 requestId, uint256 responseIndex, uint256 overlapIndex) private view returns (bool)
    {
        uint256 rolledNumber = (vrfResponses[requestId][responseIndex] % vrfBets[requestId][responseIndex][overlapIndex][4]) + 1;

        if(rolledNumber >= vrfBets[requestId][responseIndex][overlapIndex][2] && rolledNumber <= vrfBets[requestId][responseIndex][overlapIndex][3])
        {
            return true;
        }

        return false;
    }

    /*
        @dev use ETH_INDEX in parameter to return ETH balance

        @param token contract

        @return amount of tokens or ETH in this contract
    */
    function _getLiquidityBalance(address token) private view returns (uint256)
    {
        if(token == address(0))
        {
            return address(this).balance;
        }

        return IERC20(token).balanceOf(address(this));
    }

    /*
        @param address adding liquidity
        @param token contract being added
        @param amount of tokens added
    */
    function _addLiquidity(address from, address token, uint256 amount) private
    {
        require(amount > 0);

        if(token != address(0))
        {
            IERC20(token).transferFrom(from, address(this), amount);

            emit AddTokenLiquidity(from, token, amount);
        }
        else
        {
            emit AddETHLiquidity(from, amount);
        }
    
        _shares[token][from] += amount;
        _shareTotals[token] += amount;
    }

    /*
        @param address removing liquidity
        @param contract of token being removed
        @param amount of shares being removed
    */
    function _removeLiquidity(address from, address token, uint256 shareAmount) private
    {
        require(shareAmount <= _shares[token][from]);

        uint256 contractBalance = _getLiquidityBalance(token);

        uint256 amount = contractBalance / (_shareTotals[token] / shareAmount); 

        require(contractBalance > amount);

        _shares[token][from] -= shareAmount;
        _shareTotals[token] -= shareAmount;

        if(token == address(0))
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

    /*
        @param requestor address
        @param bet token address
        @param expected amount of ETH to bet
        @param bets [VRF response][Overlap bet][Wager, PayoutOdds, Lower, Upper, Range]
        @param keyHash corresponds to a particular oracle job which uses that key for generating the VRF proof
        @param subId is the ID of the VRF subscription. Must be funded with the minimum subscription balance required for the selected keyHash
        @param confirmations is how many blocks you'd like the oracle to wait before responding to the request
        @param gasLimit is how much gas you'd like to receive in your fulfillRandomWords callback

        @return VRF request ID
    */
    function _requestRoll(address from, address token, uint256 amount, uint256[5][][] memory bets, bytes32 keyHash, uint64 subId, uint16 confirmations, uint32 gasLimit) private returns (uint256)
    {
        uint256 totalBet = 0;

        for(uint256 i = 0; i < bets.length; i++)
        {
            for(uint256 a = 0; a < bets[i].length; a++)
            {
                //Upper bound must be greater than lower bound
                require(bets[i][a][3] >= bets[i][a][2]);

                uint256 winRange = (bets[i][a][3] - bets[i][a][2]) + 1;
                uint256 loseOdds = ((bets[i][a][4] - winRange) * 100) / winRange;

                uint256 houseEdge = (loseOdds - bets[i][a][1]) * ((winRange * 1000) / bets[i][a][4]);

                // House edge must be greater than 1%
                require(houseEdge >= 1000);

                totalBet += bets[i][a][0];
            }
        }

        // Check roll amount no greater than .01% of liquidity
        require(totalBet <= _getLiquidityBalance(token) / 10000);

        if(token != address(0))
        {
            IERC20(token).transferFrom(from, address(this), amount);
        }
        else
        {
            require(amount >= totalBet);
        }

        return requestRandomWords(from, bets, token, keyHash, subId, confirmations, gasLimit);
    }

    /*
        @param VRF request ID
    */
    function _withdrawRoll(uint256 requestId) public
    {
        require(vrfWithdrawn[requestId] == false);
        vrfWithdrawn[requestId] = true;

        uint256 totalPayout = 0;

        for(uint256 i = 0; i < vrfBets[requestId].length; i++)
        {
            for(uint256 a = 0; a < vrfBets[requestId][i].length; a++)
            {
                if(_isWinningBet(requestId, i, a))
                {
                    totalPayout += vrfBets[requestId][i][a][0] + ((vrfBets[requestId][i][a][0] * vrfBets[requestId][i][a][1]) / 100);
                }
            }
        }

        if(vrfTokens[requestId] == address(0))
        {
            (bool success,) = vrfRequestors[requestId].call{value: totalPayout}("");
            require(success);

            emit WithdrawETH(vrfRequestors[requestId], totalPayout);
        }
        else
        {
            IERC20(vrfTokens[requestId]).transfer(vrfRequestors[requestId], totalPayout);

            emit WithdrawToken(vrfRequestors[requestId], vrfTokens[requestId], totalPayout);
        }
    }
}