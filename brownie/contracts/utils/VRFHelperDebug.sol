// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IHousePool.sol";

contract VRFHelperDebug {
    mapping(uint256 => uint256[]) internal _responses;

    uint256 internal _nonce;

    constructor() {
    }

    function _requestRandomWords() internal returns (uint256 requestId) {
        requestId = _nonce;
        _nonce++;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external {
        _responses[requestId] = randomWords;
    }
}