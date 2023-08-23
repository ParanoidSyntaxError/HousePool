// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/math/Math.sol";

import "../interfaces/IHousePool.sol";

library HousePoolMath {
    uint256 public constant HOUSE_EDGE_SCALE = 1000;
    uint256 public constant CHANCE_SCALE = 100000;
    uint256 public constant MAX_CHANCE = 100000;
    uint256 public constant PAYOUTMULTI_SCALE = 1000;
    uint256 public constant MINIMUM_HOUSE_EDGE = 10000; // 1.0%
    uint256 public constant MAX_BET_PERCENT = 5000;     // 0.5%

    uint256 public constant MATH_SCALE = 1000000;

    function expandRandom(uint256 random) public pure returns (uint256 original, uint256 expanded) {
        return (random, uint256(keccak256(abi.encode(random, 1))));
    }

    function weightRandom(uint256 range, uint256 random) public pure returns (uint256) {
        unchecked {
            return Math.sqrt((random % range) * MATH_SCALE);
        }
    }

    function isWinner(IHousePool.UnpackedBet memory unpackedBet, uint256 random) public pure returns (bool) {
        uint256 roll = random % MAX_CHANCE;

        if(roll < unpackedBet.minWinChance) {
            return true;
        }

        return false;
    }

    function payoutMulti(IHousePool.UnpackedBet memory unpackedBet, uint256 random) public pure returns (uint256) {
        if(isWinner(unpackedBet, random)) {
            if (unpackedBet.minWinChance == unpackedBet.maxWinChance || unpackedBet.minPayoutMulti == unpackedBet.maxPayoutMulti) {
                return unpackedBet.minPayoutMulti;
            }

            (,uint256 expandedRandom) = expandRandom(random);
            uint256 winRoll = weightRandom(unpackedBet.minWinChance - unpackedBet.maxWinChance, expandedRandom);
            uint256 winRange = Math.sqrt((unpackedBet.minWinChance - unpackedBet.maxWinChance) * MATH_SCALE);
            uint256 payoutRange = unpackedBet.maxPayoutMulti - unpackedBet.minPayoutMulti;
            uint256 payoutIncrement = (payoutRange * MATH_SCALE) / winRange;
            return ((payoutIncrement * (winRange - winRoll)) / MATH_SCALE) + unpackedBet.minPayoutMulti;
        }

        return 0;
    }

    function payoutAmount(IHousePool.UnpackedBet memory unpackedBet, uint256 random) public pure returns (uint256) {
        if(isWinner(unpackedBet, random)) {
            uint256 multi = payoutMulti(unpackedBet, random);
            return (unpackedBet.principle * multi) / PAYOUTMULTI_SCALE;
        }

        return 0;
    }

    function houseEdge(IHousePool.UnpackedBet memory unpackedBet) external pure returns (uint256) {
        uint256 expectedWinnings = ((unpackedBet.minWinChance * unpackedBet.minPayoutMulti) + (unpackedBet.maxWinChance * unpackedBet.maxPayoutMulti)) / 2;
        uint256 expectedLosses = ((MAX_CHANCE - 1) - unpackedBet.minWinChance) * PAYOUTMULTI_SCALE;
        return expectedLosses - expectedWinnings;
    }

    function packBet(IHousePool.UnpackedBet memory unpackedBet) external pure returns (IHousePool.PackedBet memory packedBet){
        packedBet.principle = unpackedBet.principle;

        packedBet.packedData = unpackedBet.minWinChance;
        packedBet.packedData |= unpackedBet.maxWinChance << 64;
        packedBet.packedData |= unpackedBet.minPayoutMulti << 128;
        packedBet.packedData |= unpackedBet.maxPayoutMulti << 192;
    }

    function unpackBet(IHousePool.PackedBet memory packedBet) external pure returns (IHousePool.UnpackedBet memory){
        return IHousePool.UnpackedBet(
            packedBet.principle,
            uint64(packedBet.packedData),
            uint64(packedBet.packedData >> 64),
            uint64(packedBet.packedData >> 128),
            uint64(packedBet.packedData >> 192)
        );
    }

    /*
    //  - Roulette -
    // payoutMultiplier - 35000
    // winOdds - 1
    // loseOdds - 36
    // HouseEdge - 27027 (2.7027%)
    function houseEdge(uint256 payoutMultiplier, uint256 winOdds, uint256 loseOdds) external pure returns (uint256) {
        unchecked {
            uint256 range = winOdds + loseOdds;
            return ((loseOdds * _mathScale) / range) - ((payoutMultiplier * ((winOdds * _mathScale) / range)) / HOUSE_EDGE_SCALE);   
        }
    }

    function payoutMulti(uint256 winRange, uint256 minPayout, uint256 maxPayout, uint256 weightedPayoutRandom) public pure returns (uint256 amount) {
        unchecked {
            uint256 weightedWinRange = Math.sqrt(winRange * _mathScale);
            uint256 payoutRange = maxPayout - minPayout;
            uint256 payoutIncrement = (payoutRange * _mathScale) / weightedWinRange;
            amount = ((payoutIncrement * (weightedWinRange - weightedPayoutRandom)) / _mathScale) + minPayout;   
        }
    }

    function payoutAmount(IHousePool.Bet memory bet, uint256 baseRandom) external pure returns (uint256) {
        (uint256 rollRandom, uint256 payoutRandom) = expandRandom(baseRandom);

        if(isWinningBet(bet.startWinOdds, bet.minWinOdds, bet.oddsRange, rollRandom)) {
            unchecked {
                uint256 weightedRandom = weightRandom(bet.oddsRange, payoutRandom);
                uint256 winRange = bet.minWinOdds - bet.maxWinOdds;
                return (bet.principle + (bet.principle * payoutMulti(winRange, bet.minPayoutMulti, bet.maxPayoutMulti, weightedRandom))) / PAYOUTMULTI_SCALE;   
            }
        }

        return 0;
    }
    */
}