// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../Shared/Ownable.sol";
import "./IHousePool.sol";
import "../Shared/IERC20.sol";

// TODO: Big wheel
// TODO: Coin flip
// TODO: Reward HousePool interactions with SMCS
// TODO: Comments

contract SmartCasino is Ownable
{
    struct Bet
    {
        address owner;
        uint256 amount;
    }

    struct RollID
    {
        uint256 requestId;
        uint256[2][] indexes;
    }

    struct GameData
    {
        mapping(address => mapping(uint256 => RollID)) rollIds;
        mapping(address => uint256) rollIdLengths;

        mapping(address => mapping(uint256 => Bet)) bets;
        mapping(address => uint256) betLengths;
    }

    IHousePool public immutable housePool;

    address private HOUSE_POOL_ADDRESS;

    GameData private _coinFlip;

    mapping(address => mapping(address => uint256)) private _tokenBalances;

    bytes32 private _keyHash = 0xd4bb89654db74673a187bd804519e65e3f71a52bc55f11da7601a13dcf505314;
    uint32 private _callbackGasLimit = 100000;
    uint16 private _requestConfirmations = 3;
    uint64 private _subscriptionId;

    constructor()
    {
        housePool = IHousePool(HOUSE_POOL_ADDRESS);
    }

    function setVrfSettings(address housePoolContract, bytes32 keyHash, uint64 subId, uint16 confirmations, uint32 gasLimit) external onlyOwner returns(bool)
    {
        HOUSE_POOL_ADDRESS = housePoolContract; // DEBUG

        _keyHash = keyHash;
        _subscriptionId = subId;
        _requestConfirmations = confirmations;
        _callbackGasLimit = gasLimit;

        return true;
    }

    function getVrfSettings() external view returns(bytes32, uint64, uint16, uint32)
    {
        return (_keyHash, _subscriptionId, _requestConfirmations, _callbackGasLimit);
    }

    function flipCoinBet(address token, uint256 amount) public returns(bool)
    {
        require(amount <= _tokenBalances[token][msg.sender]);

        if(_coinFlip.rollIds[msg.sender][_coinFlip.rollIdLengths[msg.sender]].requestId != 0)
        {
            _coinFlip.rollIdLengths[msg.sender] += 1;
        }

        _coinFlip.rollIds[msg.sender][_coinFlip.rollIdLengths[msg.sender]].indexes.push([0, _coinFlip.betLengths[token]]);

        _coinFlip.bets[token][_coinFlip.betLengths[token]] = Bet(msg.sender, amount);

        _coinFlip.betLengths[token] += 1;

        return true;
    }

    function flipCoinRoll(address token) public 
    {
        uint256[5][][] memory bets = new uint256[5][][](_coinFlip.betLengths[token]);

        for(uint256 i = 0; i < bets.length; i++)
        {
            bets[i] = new uint256[5][](1);
            bets[i][0] = [_coinFlip.bets[token][i].amount, _coinFlip.bets[token][i].amount, 1, 99, 200];
        }

        uint256 requestId = housePool.requestTokenRoll(token, bets, _keyHash, _subscriptionId, _requestConfirmations, _callbackGasLimit);

        for(uint256 i = 0; i < bets.length; i++)
        {
            _coinFlip.rollIds[_coinFlip.bets[token][i].owner][_coinFlip.rollIdLengths[_coinFlip.bets[token][i].owner]].requestId = requestId;
        }

        _coinFlip.betLengths[token] = 0;
    }

    function depositETH() public payable returns(bool)
    {
        _tokenBalances[housePool.getETHIndex()][msg.sender] += msg.value;

        return true;
    }

    function depositTokens(address token, uint256 amount) public returns(bool)
    {
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        _tokenBalances[token][msg.sender] += amount;

        return true;
    }

    function claimCoinFlipWinnings() public returns (bool)
    {
        for(uint256 i = 0; i < _coinFlip.rollIdLengths[msg.sender]; i++)
        {
            (, address token,, uint256[5][][] memory bets) = housePool.getRoll(_coinFlip.rollIds[msg.sender][i].requestId);

            for(uint256 a = 0; a < _coinFlip.rollIds[msg.sender][i].indexes.length; a++)
            {
                if(housePool.isWinningBet(_coinFlip.rollIds[msg.sender][i].requestId, _coinFlip.rollIds[msg.sender][i].indexes[a][0], _coinFlip.rollIds[msg.sender][i].indexes[a][1]))
                {                 
                    _tokenBalances[token][msg.sender] += bets[_coinFlip.rollIds[msg.sender][i].indexes[a][0]][_coinFlip.rollIds[msg.sender][i].indexes[a][1]][1];
                }
            }
        }

        _coinFlip.rollIdLengths[msg.sender] = 0;

        return true;
    }
}
