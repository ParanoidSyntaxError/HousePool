// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../Shared/LinkTokenInterface.sol";
import "../Shared/VRFCoordinatorV2Interface.sol";
import "../Shared/VRFConsumerBaseV2.sol";

// DONE: Pack VRF bet data into struct

// TODO: Comments

contract VRFHelper is VRFConsumerBaseV2
{
    struct Roll
    {
        address requestor;
        uint256[5][][] bets;
        address token;
        uint256[] responses;
        bool withdrawn;
    }

    VRFCoordinatorV2Interface public vrfCoordinator;
    LinkTokenInterface public linkToken;

    address private constant VRF_ADDRESS = 0x6A2AAd07396B36Fe02a22b33cf443582f682c82f;
    address private constant LINK_ADDRESS = 0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06;

    mapping(uint256 => Roll) internal rolls;

    constructor() VRFConsumerBaseV2(VRF_ADDRESS)
    {
        vrfCoordinator = VRFCoordinatorV2Interface(VRF_ADDRESS);
        linkToken = LinkTokenInterface(LINK_ADDRESS);
    }

    // Assumes the subscription is funded sufficiently
    // wordCount cant exceed VRFCoordinatorV2.MAX_NUM_WORDS
    function requestRandomWords(address from, uint256[5][][] memory bets, address token, bytes32 keyHash, uint64 subscriptionId, uint16 requestConfirmations, uint32 callbackGasLimit) internal returns (uint256)
    {
        require(bets.length <= 500);

        (,,,address[] memory consumers) = vrfCoordinator.getSubscription(subscriptionId);

        for(uint256 i = 0; i < consumers.length; i++)
        {
            if(from == consumers[i])
            {
                uint256 requestId = vrfCoordinator.requestRandomWords(keyHash, subscriptionId, requestConfirmations, callbackGasLimit, (uint32)(bets.length));

                rolls[requestId] = Roll(from, bets, token, new uint256[](0), false);

                return requestId;
            }
        }

        revert();
    }

    // VRF callback
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal virtual override 
    {
        rolls[requestId].responses = randomWords;
    }
}