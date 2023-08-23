// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/IHousePool.sol";

import "./token/HousePoolLiquidityToken.sol";

import "./utils/VRFHelper.sol";
import "./utils/HousePoolMath.sol";

contract HousePool is IHousePool, VRFHelper, ERC721 {
    // Request ID => Request data
    mapping(uint256 => RequestData) internal _requests;
    uint256 internal _totalRequests;

    // Request ID => VRF index => Overlap index => Is bet collected
    mapping(uint256 => mapping(uint256 => mapping(uint256 => bool))) internal _betCollected;

    // Asset => Liquidity token
    mapping(address => address) internal _liquidityTokens;
    
    // Operator ID => Token contract => Balance
    mapping(uint256 => mapping(address => uint256)) internal _operatorBalances;
    uint256 internal _totalOperators;

    constructor(address vrf, address link) VRFHelper(vrf, link) ERC721("", "") {

    }

    receive() external payable {}

    /*
        @param HousePool request ID
    */
    modifier requestExists(uint256 requestId) {
        require(requestId < _totalRequests);
        _;
    }

    /*
        @param HousePool request parameters

        @return HousePool request ID
    */
    function request(RequestParams calldata requestParams) external override returns (uint256 requestId) {
        // Must request at least one bet
        require(requestParams.packedBets.length > 0);
        
        // Total amount of tokens bet in this request
        uint256 betAmount;

        // VRF responses
        for(uint256 v; v < requestParams.packedBets.length; v++) {
            // Overlapping bets
            for(uint256 o; o < requestParams.packedBets[v].length; o++) {
                UnpackedBet memory unpackedBet = HousePoolMath.unpackBet(requestParams.packedBets[v][o]);

                require(HousePoolMath.houseEdge(unpackedBet) >= HousePoolMath.MINIMUM_HOUSE_EDGE);

                // Add bet to requests total bet amount
                betAmount += unpackedBet.principle;
            }
        }

        require(betAmount <= IERC4626(_liquidityTokens[requestParams.token]).totalAssets() / HousePoolMath.MAX_BET_PERCENT);

        SafeERC20.safeTransferFrom(
            IERC20(requestParams.token), 
            msg.sender, 
            address(this), 
            betAmount
        );

        // Send VRF request using VRFHelper.sol
        uint256 vrfRequestId = _requestRandomWords(
            msg.sender, 
            requestParams.subscriptionId, 
            requestParams.keyHash,
            requestParams.requestConfirmations,
            requestParams.callbackGasLimit, 
            uint32(requestParams.packedBets.length)
        );

        requestId = _totalRequests;

        _requests[requestId] = RequestData(
            requestParams.operatorId, 
            requestParams.packedBets, 
            requestParams.token, 
            vrfRequestId
        );
        _totalRequests++;
    }

    /*
        @param HousePool request ID's
        @param Requests VRF indexes
        @param Requests overlap indexes

        @return Collected amount
    */
    function collectBets(CollectionParams[] calldata collectionParams) external override returns (uint256 amount) {
        for(uint256 i; i < collectionParams.length; i++) {
            require(_requests[collectionParams[0].requestId].token == _requests[collectionParams[i].requestId].token);
            require(_requests[collectionParams[0].requestId].operatorId == _requests[collectionParams[i].requestId].operatorId);

            for(uint256 v; v < collectionParams[i].vrfIndexes.length; v++) {
                for(uint256 o; o < collectionParams[i].overlapIndexes[v].length; o++) {
                    require(_betCollected[collectionParams[i].requestId][collectionParams[i].vrfIndexes[v]][collectionParams[i].overlapIndexes[v][o]] == false);

                    UnpackedBet memory unpackedBet = HousePoolMath.unpackBet(_requests[collectionParams[0].requestId].packedBets[collectionParams[i].vrfIndexes[v]][collectionParams[i].overlapIndexes[v][o]]);

                    amount += HousePoolMath.payoutAmount(
                        unpackedBet,
                        _responses[collectionParams[i].requestId][collectionParams[i].vrfIndexes[v]]
                    );
                    _betCollected[collectionParams[i].requestId][collectionParams[i].vrfIndexes[v]][collectionParams[i].overlapIndexes[v][o]] = true;
                }
            }
        }

        _operatorBalances[_requests[collectionParams[0].requestId].operatorId][_requests[collectionParams[0].requestId].token] += amount;
    }

    /*
        @param Operator token ID
        @param Token receiver address
        @param Withdrawn token contract

        @return Withdrawn amount
    */
    function withdrawOperatorBalance(uint256 operatorId, address receiver, address asset) external override returns (uint256 amount) {
        require(_ownerOf(operatorId) == msg.sender);
        
        amount = _operatorBalances[operatorId][asset];

        SafeERC20.safeTransfer(
            IERC20(asset), 
            receiver, 
            amount
        );
    }
    
    /*
        @param

        @return
    */
    function deployLiquidityToken(address asset) external override returns (address token) {
        require(_liquidityTokens[asset] == address(0));

        token = address(new HousePoolLiquidityToken(
            "HousePool Liquidity Token",
            string(abi.encodePacked("hp", IERC20Metadata(asset).symbol())), 
            asset, 
            address(this)
        ));

        _liquidityTokens[asset] = token;

        SafeERC20.safeIncreaseAllowance(
            IERC20(asset), 
            token, 
            type(uint256).max
        );
    }

    /*
        @param

        @return
    */
    function mintOperator(address receiver) external override returns (uint256 operatorId) {
        operatorId = _totalOperators;

        _safeMint(
            receiver, 
            operatorId
        );
        _totalOperators++;
    }
    
    function _collectionAmount(CollectionParams[] calldata collectionParams) internal view returns (uint256 amount) {
        for(uint256 i; i < collectionParams.length; i++) {
            require(_requests[collectionParams[0].requestId].token == _requests[collectionParams[i].requestId].token);
            require(_requests[collectionParams[0].requestId].operatorId == _requests[collectionParams[i].requestId].operatorId);

            for(uint256 v; v < collectionParams[i].vrfIndexes.length; v++) {
                for(uint256 o; o < collectionParams[i].overlapIndexes[v].length; o++) {
                    require(_betCollected[collectionParams[i].requestId][collectionParams[i].vrfIndexes[v]][collectionParams[i].overlapIndexes[v][o]] == false);

                    UnpackedBet memory unpackedBet = HousePoolMath.unpackBet(
                        _requests[collectionParams[i].requestId].packedBets[collectionParams[i].vrfIndexes[v]][collectionParams[i].overlapIndexes[v][o]]
                    );

                    amount += HousePoolMath.payoutAmount(
                        unpackedBet, 
                        _responses[collectionParams[i].requestId][collectionParams[i].vrfIndexes[v]]
                    );
                }
            }
        }
    }

    function _availableLiquidity(address asset) internal view returns (uint256) {
        return IERC20(asset).totalSupply();
    }

    /*
        @param

        @return
    */
    function getResponse(uint256 vrfRequestId) external view returns (uint256[] memory) {
        return _responses[vrfRequestId];
    }

    /*
        @param

        @return
    */
    function getRequest(uint256 requestId) external view requestExists(requestId) returns (RequestData memory) {
        return _requests[requestId];
    }

    /*
        @return
    */
    function totalRequests() external view returns (uint256) {
        return _totalRequests;
    }

    /*
        @param

        @return
    */
    function collectionAmount(CollectionParams[] calldata collectionParams) external view override returns (uint256 amount) {
        return _collectionAmount(collectionParams);
    }

    /*
        @param

        @return
    */
    function liquidityToken(address token) external view returns (address) {
        return _liquidityTokens[token];
    }

    /*
        @param
        @param

        @return
    */
    function operatorBalance(uint256 id, address token) external view override returns (uint256) {
        return _operatorBalances[id][token];
    }

    /*
        @return
    */
    function totalOperators() external view returns (uint256) {
        return _totalOperators;
    }

    /*
        @param
        @param
        @param

        @return
    */
    function isWinningBet(uint256 requestId, uint256 vrfIndex, uint256 overlapIndex) external view override returns (bool) {
        UnpackedBet memory unpackedBet = HousePoolMath.unpackBet(_requests[requestId].packedBets[vrfIndex][overlapIndex]);

        return HousePoolMath.isWinner(unpackedBet, _responses[requestId][vrfIndex]);
    }

    /*
        @param
        @param
        @param

        @return
    */
    function isBetCollected(uint256 requestId, uint256 vrfIndex, uint256 overlapIndex) external view returns (bool) {
        return _betCollected[requestId][vrfIndex][overlapIndex];
    }
}