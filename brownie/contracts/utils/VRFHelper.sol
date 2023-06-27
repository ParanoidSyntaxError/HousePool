// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

import "../interfaces/IHousePool.sol";

contract VRFHelper is VRFConsumerBaseV2 {
    VRFCoordinatorV2Interface public vrfCoordinator;
    LinkTokenInterface public linkToken;

    mapping(uint256 => uint256[]) internal _responses;

    constructor(address vrf, address link) VRFConsumerBaseV2(vrf) {
        vrfCoordinator = VRFCoordinatorV2Interface(vrf);
        linkToken = LinkTokenInterface(link);
    }

    function _vrfOwner(uint64 subscriptionId) internal view returns (address owner) {
        (,,owner,) = vrfCoordinator.getSubscription(subscriptionId);
    }

    function _requestRandomWords(address from, uint64 subscriptionId, bytes32 keyHash, uint16 requestConfirmations, uint32 callbackGasLimit, uint32 randomWords) internal returns (uint256) {
        (,,,address[] memory consumers) = vrfCoordinator.getSubscription(subscriptionId);
        
        bool isConsumer;
        for(uint256 i; i < consumers.length; i++) {
            if(from == consumers[i]) {
                isConsumer = true;
            }
        }
        require(isConsumer);

        return vrfCoordinator.requestRandomWords(keyHash, subscriptionId, requestConfirmations, callbackGasLimit, randomWords);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal virtual override {
        _responses[requestId] = randomWords;
    }
}