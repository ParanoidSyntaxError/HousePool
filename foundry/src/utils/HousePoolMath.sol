// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/utils/math/Math.sol";

import "../interfaces/IHousePool.sol";

library HousePoolMath {
    //uint256 public constant HOUSE_EDGE_SCALE = 1000;
    uint256 public constant CHANCE_SCALE = 100000;
    uint256 public constant MAX_CHANCE = 100000;
    uint256 public constant PAYOUTMULTI_SCALE = 1000;

    // TODO: 1%
    uint256 public constant MINIMUM_HOUSE_EDGE = 10000;
    // TODO: 0.0001%
    uint256 public constant MAX_BET_PERCENT = 5000;

    uint256 public constant MATH_SCALE = 1000000;

    function expandRandom(uint256 random) public pure returns (uint256) {
        return uint256(keccak256(abi.encode(random, 1)));
    }

    function weightRandom(uint256 range, uint256 random) public pure returns (uint256) {
        unchecked {
            return Math.sqrt((random % range) * MATH_SCALE);
        }
    }

    function isWinner(IHousePool.Bet memory bet, uint256 random) public pure returns (bool) {
        uint256 roll = random % MAX_CHANCE;

        if(roll >= bet.startWinChance && roll <= bet.endWinChance) {
            return true;
        }

        return false;
    }

    function payoutMulti(IHousePool.Bet memory bet, uint256 random) public pure returns (uint256) {
        if(isWinner(bet, random)) {
            if (bet.minPayoutMulti == bet.maxPayoutMulti) {
                return bet.minPayoutMulti;
            }

            uint256 expandedRandom = expandRandom(random);
            uint256 payoutIncrement = (bet.maxPayoutMulti - bet.minPayoutMulti) * MATH_SCALE;
            uint256 winRoll = MATH_SCALE - weightRandom(MATH_SCALE, expandedRandom);
            return ((payoutIncrement * winRoll) / (MATH_SCALE * MATH_SCALE)) + bet.minPayoutMulti;
        }

        return 0;
    }

    function payoutAmount(IHousePool.Bet memory bet, uint256 random) public pure returns (uint256) {
        if(isWinner(bet, random)) {
            uint256 multi = payoutMulti(bet, random);
            return (bet.principle * multi) / PAYOUTMULTI_SCALE;
        }

        return 0;
    }

    function houseEdge(IHousePool.Bet memory bet) external pure returns (uint256) {
        uint256 winRange = bet.endWinChance - bet.startWinChance;
        uint256 expectedWinnings = ((winRange * bet.minPayoutMulti) + bet.maxPayoutMulti) / 2;
        uint256 expectedLosses = ((MAX_CHANCE - 1) - winRange) * PAYOUTMULTI_SCALE;

        return expectedLosses - expectedWinnings;
    }

    function packBet(IHousePool.Bet memory bet) external pure returns (uint256 packedBet){
        packedBet = bet.principle;
        packedBet |= bet.startWinChance << 128;
        packedBet |= bet.endWinChance << 160;
        packedBet |= bet.minPayoutMulti << 192;
        packedBet |= bet.maxPayoutMulti << 224;
    }

    function unpackBet(uint256 packedBet) external pure returns (IHousePool.Bet memory){
        return IHousePool.Bet(
            uint128(packedBet),
            uint32(packedBet >> 128),
            uint32(packedBet >> 160),
            uint32(packedBet >> 192),
            uint32(packedBet >> 224)
        );
    }
}