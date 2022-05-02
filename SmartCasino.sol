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
    struct CoinFlipBet
    {
        uint256[2] amounts;
        uint256 timestamp;
    }

    struct CoinFlipData
    {
        uint256 lastTimestamp;

        //[0] = heads
        //[1] = tails
        uint256[2] currentBetTotals;

        //[token][timestamp] = requestId
        mapping(address => mapping(uint256 => uint256)) requestIds;

        //[token][player][index] = bet
        mapping(address => mapping(address => mapping(uint256 => CoinFlipBet))) bets;
        //[token][player] = length
        mapping(address => mapping(address => uint256)) betLengths;
    }

    IHousePool public housePool;

    CoinFlipData private _coinFlip;

    mapping(address => mapping(address => uint256)) public _tokenBalances;

    bytes32 private _keyHash;
    uint32 private _callbackGasLimit;
    uint16 private _requestConfirmations;
    uint64 private _subscriptionId;

    constructor()
    {
        housePool = IHousePool(0xb4128706d9Bf5088208C07b12Ef7d86d1c636Bd4);

        setVrfSettings(0xd4bb89654db74673a187bd804519e65e3f71a52bc55f11da7601a13dcf505314, 688, 3, 100000);
    }

    receive() external payable {}

    function setVrfSettings(bytes32 keyHash, uint64 subId, uint16 confirmations, uint32 gasLimit) public returns(bool)
    {
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

    function betCoinFlip(address token, uint256[2] memory amounts) public
    {
        //Does account have enough to bet
        require(amounts[0] + amounts[1] <= _tokenBalances[token][msg.sender]);

        //Remove amount from account balance
        _tokenBalances[token][msg.sender] -= amounts[0] + amounts[1];

        if(_coinFlip.bets[token][msg.sender][_coinFlip.betLengths[token][msg.sender] - 1].timestamp == _coinFlip.lastTimestamp)
        {
            //Add to bet
            _coinFlip.bets[token][msg.sender][_coinFlip.betLengths[token][msg.sender] - 1].amounts[0] += amounts[0];
            _coinFlip.bets[token][msg.sender][_coinFlip.betLengths[token][msg.sender] - 1].amounts[1] += amounts[1];
        }
        else
        {
            //New bet
            _coinFlip.bets[token][msg.sender][_coinFlip.betLengths[token][msg.sender]] = CoinFlipBet(amounts, _coinFlip.lastTimestamp);

            _coinFlip.betLengths[token][msg.sender] += 1;
        }

        _coinFlip.currentBetTotals[0] += amounts[0];
        _coinFlip.currentBetTotals[1] += amounts[1];
    }

    function claimCoinFlip(address token, address account) public
    {
        for(uint256 i = 0; i < _coinFlip.betLengths[token][account]; i++)
        {
            //if()
        }

        _coinFlip.betLengths[token][account] = 0;

        /*
        struct CoinFlipData
        {
            uint256 lastTimestamp;

            //[0] = heads
            //[1] = tails
            uint256[2] currentBetTotals;

            //[token][timestamp] = requestId
            mapping(address => mapping(uint256 => uint256)) requestIds;

            //[token][player][index] = bet
            mapping(address => mapping(address => mapping(uint256 => CoinFlipBet))) bets;
            //[token][player] = length
            mapping(address => mapping(address => uint256)) betLengths;
        }
        */
    }

    function rollCoinFlip(address token) public
    {
        //Prevent overwriting timestamp to requestID mapping
        require(_coinFlip.lastTimestamp != block.timestamp);

        //Build bets array for house pool
        uint256[5][][] memory bets = new uint256[5][][](1);
        bets[0] = new uint256[5][](2);

        //Heads
        bets[0][0] = [_coinFlip.currentBetTotals[0], _coinFlip.currentBetTotals[0], 1, 99, 200];
        //Tails
        bets[0][1] = [_coinFlip.currentBetTotals[1], _coinFlip.currentBetTotals[1], 101, 200, 200];

        //Total tokens bet, amount to be sent to house pool
        uint256 totalBet = _coinFlip.currentBetTotals[0] + _coinFlip.currentBetTotals[0];

        //Temp request ID
        uint256 requestId = 0;

        if(token == housePool.getETHIndex())
        {
            //ETH house pool roll request
            requestId = housePool.requestETHRoll{value : totalBet}(bets, _keyHash, _subscriptionId, _requestConfirmations, _callbackGasLimit);
        }
        else
        {
            //Approve tokens for transfer by house pool
            IERC20(token).approve((address)(housePool), totalBet);

            //ERC20 token house pool roll request
            requestId = housePool.requestTokenRoll(token, bets, _keyHash, _subscriptionId, _requestConfirmations, _callbackGasLimit);
        }

        //Assign request ID to timestamp
        _coinFlip.requestIds[token][_coinFlip.lastTimestamp] = requestId;

        //Get coin flip ready for the next round
        _restartCoinFlip();
    }

    function _restartCoinFlip() private
    {
        _coinFlip.currentBetTotals[0] = 0;
        _coinFlip.currentBetTotals[1] = 0;
        _coinFlip.lastTimestamp = block.timestamp;
    }
}
