// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IHousePool {
    struct RequestParams {
        uint256 operatorId;
        PackedBet[][] packedBets;
        address token;
        uint64 subscriptionId;
        bytes32 keyHash;
        uint16 requestConfirmations;
        uint32 callbackGasLimit;
    }

    struct RequestData {
        uint256 operatorId;
        PackedBet[][] packedBets;
        address token;
        uint256 vrfRequestId;
    }

    struct PackedBet {
        uint256 principle;
        uint256 packedData;
    }

    struct UnpackedBet {
        uint256 principle;
        uint256 minWinChance;
        uint256 maxWinChance;
        uint256 minPayoutMulti;
        uint256 maxPayoutMulti;
    }

    struct CollectionParams {
        uint256 requestId;
        uint256[] vrfIndexes;
        uint256[][] overlapIndexes;
    }

    function request(RequestParams calldata requestParams) external returns (uint256 requestId);

    function collectBets(CollectionParams[] calldata collectionParams) external returns (uint256 amount);

    function withdrawOperatorBalance(uint256 operatorId, address receiver, address asset) external returns (uint256 amount);

    function deployLiquidityToken(address asset) external returns (address token);

    function mintOperator(address receiver) external returns (uint256 operatorId);

    function getResponse(uint256 vrfRequestId) external view returns (uint256[] memory response);

    function getRequest(uint256 requestId) external view returns (RequestData memory request);
    function totalRequests() external view returns (uint256 totalRequests);

    function collectionAmount(CollectionParams[] calldata collectionParams) external view returns (uint256 amount);

    function liquidityToken(address asset) external view returns (address token);

    function operatorBalance(uint256 operatorId, address asset) external view returns (uint256 balance);
    function totalOperators() external view returns (uint256 totalOperators);

    function isWinningBet(uint256 requestId, uint256 vrfIndex, uint256 overlapIndex) external view returns (bool winner);
    function isBetCollected(uint256 requestId, uint256 vrfIndex, uint256 overlapIndex) external view returns (bool collected);
}