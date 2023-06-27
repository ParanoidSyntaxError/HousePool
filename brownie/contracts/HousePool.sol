// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "./interfaces/IHousePool.sol";
import "./interfaces/IHP20.sol";

import "./token/HP20.sol";
import "./proxy/HP20Proxy.sol";

import "./utils/VRFHelper.sol";

// TODO HousePool math library
// TODO Operator edge difference accounts
// TODO Operator NFT
// TODO Collect multiple bets
// TODO Rename receiver to operator
// TODO Operator balances
// TODO Improve house edge calculation (higher floating point + constants)

contract HousePool is IHousePool, VRFHelper, ERC721 {
    // Request ID => Request data
    mapping(uint256 => RequestData) internal _requests;
    uint256 internal _totalRequests;

    // Request ID => VRF index => Overlap index => Is bet collected
    mapping(uint256 => mapping(uint256 => mapping(uint256 => bool))) internal _betCollected;

    uint256 public constant LIQUIDITY_TOKEN_PRICE_SCALE = 10**20;

    address public immutable LiquidityTokenImplementation;
    // Token contract => HPL token contract
    mapping(address => address) internal _liquidityTokens;
    
    // Operator ID => Token contract => Balance
    mapping(uint256 => mapping(address => uint256)) internal _operatorBalances;
    uint256 internal _totalOperators;

    constructor(address vrf, address link) VRFHelper(vrf, link) ERC721("", "") {
        LiquidityTokenImplementation = address(new HP20());
    }

    receive() external payable {}

    function mintOperator(address receiver) external returns (uint256) {
        _totalOperators++;
        _safeMint(receiver, _totalOperators - 1);

        return _totalOperators - 1;
    }

    function collectBet(uint256 requestId, uint256 vrfIndex, uint256 overlapIndex) external returns (uint256) {              
        uint256 transferAmount = _collectionAmount(requestId, vrfIndex, overlapIndex);
        _betCollected[requestId][vrfIndex][overlapIndex] = true;

        IERC20(_requests[requestId].token).transfer(_ownerOf(_requests[requestId].operatorId), transferAmount);

        return transferAmount;
    }

    function collectBets(uint256[] calldata requestIds, uint256[][] calldata vrfIndexes, uint256[][][] calldata overlapIndexes) external returns (uint256) {
        uint256 transferAmount;

        for(uint256 r; r < requestIds.length; r++) {
            require(_requests[requestIds[0]].token == _requests[requestIds[r]].token);
            require(_requests[requestIds[0]].operatorId == _requests[requestIds[r]].operatorId);

            for(uint256 v; v < vrfIndexes[r].length; v++) {
                for(uint256 o; o < overlapIndexes[r][v].length; o++) {
                    uint256 payout = _collectionAmount(requestIds[r], vrfIndexes[r][v], overlapIndexes[r][v][o]);
                    transferAmount += payout;
                    _betCollected[requestIds[r]][vrfIndexes[r][v]][overlapIndexes[r][v][o]] = true;
                }
            }
        }

        IERC20(_requests[requestIds[0]].token).transfer(_ownerOf(_requests[requestIds[0]].operatorId), transferAmount);

        return transferAmount;
    }

    function request(RequestParams calldata requestParams) external override returns (uint256) {
        // Must request at least one bet
        require(requestParams.bets.length > 0);
        
        // Total amount of tokens bet in this request
        uint256 betAmount;

        // VRF responses
        for(uint256 v; v < requestParams.bets.length; v++) {
            // Overlapping bets
            for(uint256 o; o < requestParams.bets[v].length; o++) {
                // House edge must be greater than 1%
                require(_calculateHouseEdge(
                    requestParams.bets[v][o][1], 
                    requestParams.bets[v][o][2], 
                    requestParams.bets[v][o][3], 
                    requestParams.bets[v][o][4]
                ) >= 100);

                // Add bet to requests total bet amount
                betAmount += requestParams.bets[v][o][0];
            }
        }

        IERC20 erc20 = IERC20(requestParams.token);

        // Check total amount bet in this requests is less than 0.01% of the tokens liquidity pool
        require(betAmount <= erc20.balanceOf(address(this)) / 10000);

        erc20.transferFrom(msg.sender, address(this), betAmount);

        // Send VRF request using VRFHelper.sol
        uint256 requestId = _requestRandomWords(
            msg.sender, 
            requestParams.subscriptionId, 
            requestParams.keyHash,
            requestParams.requestConfirmations,
            requestParams.callbackGasLimit, 
            uint32(requestParams.bets.length)
        );

        _requests[_totalRequests] = RequestData(requestParams.operatorId, requestParams.bets, requestParams.token, requestId);
        _totalRequests++;

        return _totalRequests - 1;
    }

    function addLiquidity(address receiver, address token, uint256 amount) external override returns (uint256) {       
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
                // No tokens at risk, clear liquidity tokens
                IHP20(_liquidityTokens[token]).clearBalances();
            }
        }
        
        // TODO: What if sharePrice == 0 ?
        uint256 liquidityTokenAmount = (amount * LIQUIDITY_TOKEN_PRICE_SCALE) / _liquidityTokenPrice(token);
        IHP20(_liquidityTokens[token]).mint(receiver, liquidityTokenAmount);

        return liquidityTokenAmount;
    }

    function removeLiquidity(address receiver, address token, uint256 amount) external override returns (uint256) {
        IHP20(_liquidityTokens[token]).burnFrom(msg.sender, amount);

        // TODO: What if sharePrice == 0 ?
        uint256 tokenAmount = (amount * _liquidityTokenPrice(token)) / LIQUIDITY_TOKEN_PRICE_SCALE;
        IERC20(token).transfer(receiver, tokenAmount);

        return tokenAmount;
    }

    /**
        @dev Divide by LIQUIDITY_TOKEN_PRICE_SCALE to get floating value
    */
    function _liquidityTokenPrice(address token) internal view returns(uint256) {
        uint256 liquidityTokenSupply = IERC20(token).totalSupply();
        
        if(liquidityTokenSupply == 0) {
            return LIQUIDITY_TOKEN_PRICE_SCALE;
        }

        return (IERC20(token).balanceOf(address(this)) * LIQUIDITY_TOKEN_PRICE_SCALE) / liquidityTokenSupply;
    }
    
    function _isWinningBet(uint256 requestId, uint256 vrfIndex, uint256 overlapIndex) internal view returns (bool) {
        // Get random number from VRF response       
        uint256 random = (_responses[_requests[requestId].vrfRequestId][vrfIndex] % _requests[requestId].bets[vrfIndex][overlapIndex][4]) + 1;

        // Check the random number is within the bets lower to upper range
        if(random >= _requests[requestId].bets[vrfIndex][overlapIndex][2] && random <= _requests[requestId].bets[vrfIndex][overlapIndex][3]) {
            // Winner
            return true;
        }

        // Loser
        return false;
    }

    function _collectionAmount(uint256 requestId, uint256 vrfIndex, uint256 overlapIndex) internal view returns (uint256) {
        if(_isWinningBet(requestId, vrfIndex, overlapIndex)) {
            return _requests[requestId].bets[vrfIndex][overlapIndex][0] + ((_requests[requestId].bets[vrfIndex][overlapIndex][0] * _requests[requestId].bets[vrfIndex][overlapIndex][1]) / 100);
        }
    
        return 0;
    }

    function _calculateHouseEdge(uint256 payoutOdds, uint256 lower, uint256 upper, uint256 range) internal pure returns (uint256) {
        // Upper bound must be greater than lower bound
        require(upper >= lower);

        uint256 winRange = (upper - lower) + 1;
        uint256 loseOdds = ((range - winRange) * 100) / winRange;

        // House edge = (Odds against Success – House Odds) x Probability of Success
        return ((loseOdds - payoutOdds) * ((winRange * 1000) / range)) / 10;
    }
}