// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IHousePool {
    struct VRFSettings {
        bytes32 keyHash;
        uint16 requestConfirmations;
        uint32 callbackGasLimit;
    }

    struct RequestParams {
        address receiver;
        uint256[5][][] bets;
        address token;
        uint64 subscriptionId;
    }

    function setVrfSettings(uint64 subscriptionId, VRFSettings calldata vrfSettings) external;

    function request(RequestParams calldata requestParams, uint64 subscriptionId) external returns (uint256);
    function collectRequests(uint256[] calldata indexes) external;

    function addLiquidity(address receiver, address token, uint256 amount) external returns (uint256);
    function removeLiquidity(address receiver, address token, uint256 amount) external returns (uint256);

    function getRequest(uint256 requestIndex) external view returns(address, uint256, uint256[5][][] memory, address, bool);
    function getResponse(uint256 requestId) external view returns (uint256[] memory);

    function isWinningBet(uint256 requestIndex, uint256 vrfIndex, uint256 overlapIndex) external view returns (bool);
    function collectionAmount(uint256 requestIndex) external view returns (uint256);
    
    function calculateHouseEdge(uint256 payoutOdds, uint256 lower, uint256 upper, uint256 range) external pure returns (uint256);
}