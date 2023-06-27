// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IHousePool {
    struct RequestParams {
        uint256 operatorId;
        uint256[5][][] bets;
        address token;          
        uint64 subscriptionId;
        bytes32 keyHash;
        uint16 requestConfirmations;
        uint32 callbackGasLimit;
    }

    struct RequestData {
        uint256 operatorId;
        uint256[5][][] bets;
        address token;
        uint256 vrfRequestId;
    }

    struct CollectionData {
        uint256 requestId;
        uint256[] vrfIndexes;
        uint256[][] overlapIndexes;
    }

    function request(RequestParams calldata requestParams) external returns (uint256);

    function addLiquidity(address receiver, address token, uint256 amount) external returns (uint256);
    function removeLiquidity(address receiver, address token, uint256 amount) external returns (uint256);
}