// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "./interfaces/IHousePool.sol";
import "./interfaces/IHP20.sol";

import "./token/HP20.sol";
import "./proxy/HP20Proxy.sol";

import "./utils/VRFHelper.sol";

contract HousePool is IHousePool, VRFHelper {
    struct RequestData {
        address receiver;
        uint256[5][][] bets;
        address token;
        uint256 requestId;
        bool withdrawn;
    }

    mapping(uint256 => RequestData) internal _requests;
    uint256 internal _totalRequests;

    mapping(uint64 => VRFSettings) internal _vrfSettings;

    uint256 public constant LIQUIDITY_TOKEN_PRICE_SCALE = 10**20;

    address public immutable LiquidityTokenImplementation;
    mapping(address => address) internal _liquidityTokens;
 
    constructor(address vrf, address link) VRFHelper(vrf, link) {
        LiquidityTokenImplementation = address(new HP20());
    }

    receive() external payable {}

    function addLiquidity(address receiver, address token, uint256 amount) external {       
        IERC20Metadata erc20 = IERC20Metadata(token);

        erc20.transferFrom(msg.sender, address(this), amount);

        if(_liquidityTokens[token] == address(0)) {
            // Deploy share token contract
            address liquidityToken = address(new HP20Proxy(LiquidityTokenImplementation));
            _liquidityTokens[token] = liquidityToken;

            string memory liquidityTokenSymbol = string(abi.encodePacked("HPL-", erc20.symbol()));

            IHP20(liquidityToken).initialize(address(this), "HousePool Liquidity", liquidityTokenSymbol, erc20.decimals());
        } else {
            if(erc20.balanceOf(address(this)) == 0) {
                // No tokens at risk, so clear liquidity tokens
                IHP20(_liquidityTokens[token]).clearBalances();
            }
        }
        
        // TODO: What if sharePrice == 0 ?
        uint256 liquidityTokenAmount = (amount * LIQUIDITY_TOKEN_PRICE_SCALE) / _liquidityTokenPrice(token);
        IHP20(_liquidityTokens[token]).mint(receiver, liquidityTokenAmount);
    }

    function removeLiquidity(address receiver, address token, uint256 amount) external {
        
    }

    /*
        @dev Divide by LIQUIDITY_TOKEN_PRICE_SCALE to get floating value
    */
    function _liquidityTokenPrice(address token) internal view returns(uint256) {
        uint256 liquidityTokenSupply = IERC20(token).totalSupply();
        
        if(liquidityTokenSupply == 0) {
            return LIQUIDITY_TOKEN_PRICE_SCALE;
        }

        return (IERC20(token).balanceOf(address(this)) * LIQUIDITY_TOKEN_PRICE_SCALE) / liquidityTokenSupply;
    }

    function getRequest(uint256 requestIndex) external view override returns(address, uint256, uint256[5][][] memory, address, bool) {
        return (
            _requests[requestIndex].receiver, 
            _requests[requestIndex].requestId, 
            _requests[requestIndex].bets, 
            _requests[requestIndex].token, 
            _requests[requestIndex].withdrawn
        );
    }

    function getResponse(uint256 requestId) external view override returns (uint256[] memory) {
        return _responses[requestId];
    }

    function getHouseEdge(uint256 payoutOdds, uint256 lower, uint256 upper, uint256 range) external pure override returns (uint256) {
        return _getHouseEdge(payoutOdds, lower, upper, range);
    }

    function isWinningBet(uint256 requestIndex, uint256 vrfIndex, uint256 overlapIndex) external view override returns (bool) {
        return _isWinningBet(
            _responses[_requests[requestIndex].requestId][vrfIndex], 
            _requests[requestIndex].bets[vrfIndex][overlapIndex][2], 
            _requests[requestIndex].bets[vrfIndex][overlapIndex][3], 
            _requests[requestIndex].bets[vrfIndex][overlapIndex][4]
        );
    }

    function withdrawAmount(uint256 requestIndex) external view override returns (uint256) {
        return _withdrawAmount(requestIndex);
    }   

    function setVrfSettings(uint64 subscriptionId, VRFSettings calldata vrfSettings) external {
        require(msg.sender == _vrfOwner(subscriptionId));
        _vrfSettings[subscriptionId] = vrfSettings;
    } 

    function request(RequestParams calldata requestParams, uint64 subscriptionId) external override returns (uint256) {
        // Total amount of tokens or ETH wagered in this request
        uint256 betAmount;

        // VRF responses
        for(uint256 v; v < requestParams.bets.length; v++) {
            // Overlapping bets
            for(uint256 o; o < requestParams.bets[v].length; o++) {
                // House edge must be greater than 1%
                require(_getHouseEdge(requestParams.bets[v][o][1], requestParams.bets[v][o][2], requestParams.bets[v][o][3], requestParams.bets[v][o][4]) >= 100);

                // Add wager to requests total bet amount
                betAmount += requestParams.bets[v][o][0];
            }
        }

        IERC20 erc20 = IERC20(requestParams.token);

        // Check total amount wagered in this requests is less than .01% of the tokens liquidity pool
        require(betAmount <= erc20.balanceOf(address(this)) / 10000);

        erc20.transferFrom(msg.sender, address(this), betAmount);

        // Send VRF request using VRFHelper.sol
        uint256 requestId = _requestRandomWords(msg.sender, _vrfSettings[subscriptionId].keyHash, subscriptionId, _vrfSettings[subscriptionId].requestConfirmations, _vrfSettings[subscriptionId].callbackGasLimit, uint32(requestParams.bets.length));

        _requests[_totalRequests] = RequestData(requestParams.receiver, requestParams.bets, requestParams.token, requestId, false);
        _totalRequests++;

        return _totalRequests - 1;
    }

    function withdrawRequests(uint256[] memory requestIndexes) external override {
        for(uint256 i; i < requestIndexes.length; i++) {
            require(_requests[requestIndexes[i]].withdrawn == false);
            _requests[requestIndexes[i]].withdrawn = true;
            
            uint256 transferAmount = _withdrawAmount(requestIndexes[i]);
        
            IERC20(_requests[requestIndexes[i]].token).transfer(_requests[requestIndexes[i]].receiver, transferAmount);
        }
    }

    function _getHouseEdge(uint256 payoutOdds, uint256 lower, uint256 upper, uint256 range) internal pure returns (uint256) {
        // Upper bound must be greater than lower bound
        require(upper >= lower);

        uint256 winRange = (upper - lower) + 1;
        uint256 loseOdds = ((range - winRange) * 100) / winRange;

        // House edge = (Odds against Success – House Odds) x Probability of Success
        return ((loseOdds - payoutOdds) * ((winRange * 1000) / range)) / 10;
    }

    function _isWinningBet(uint256 random, uint256 lower, uint256 upper, uint256 range) internal pure returns (bool) {
        // Get random number from VRF response       
        uint256 rolledNumber = (random % range) + 1;

        // Check the random number is within the bets lower to upper range
        if(rolledNumber >= lower && rolledNumber <= upper) {
            // Winner
            return true;
        }

        // Loser
        return false;
    }

    function _withdrawAmount(uint256 requestIndex) internal view returns (uint256 amount) {
        for(uint256 v; v < _requests[requestIndex].bets.length; v++) {
            uint256 random = _responses[_requests[requestIndex].requestId][v];
            
            // Overlapping bets
            for(uint256 o; o < _requests[requestIndex].bets[v].length; o++) {
                if(_isWinningBet(random, _requests[requestIndex].bets[v][o][2], _requests[requestIndex].bets[v][o][3], _requests[requestIndex].bets[v][o][4])) {
                    // Add initial bet times payout odds
                    amount += _requests[requestIndex].bets[v][o][0] + ((_requests[requestIndex].bets[v][o][0] * _requests[requestIndex].bets[v][o][1]) / 100);
                }

                // The difference between the operators edge and the mandatory 1% house edge
                uint256 edgeDifference = _getHouseEdge(_requests[requestIndex].bets[v][o][1], _requests[requestIndex].bets[v][o][2], _requests[requestIndex].bets[v][o][3], _requests[requestIndex].bets[v][o][4]) - 100;
            
                amount += (_requests[requestIndex].bets[v][o][0] * edgeDifference) / 10000;
            }
        }
    }
}