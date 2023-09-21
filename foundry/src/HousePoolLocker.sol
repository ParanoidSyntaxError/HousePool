// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/token/ERC20/IERC20.sol";
import "@openzeppelin/token/ERC721/ERC721.sol";

import "@chainlink/interfaces/AggregatorV3Interface.sol";

contract HousePoolLocker is ERC721 {
    struct LockedLiquidity {
        address token;
        uint256 amount;
        uint256 unlockTimestamp;
    }
    
    mapping(uint256 => LockedLiquidity) internal _lockedLiquidity;
    uint256 internal _totalSupply;

    mapping(address => address) public PriceFeeds;

    uint256 public constant TOKEN_SCALE = 100;

    address immutable public HousePoolToken;

    constructor(address housePoolToken) ERC721("HousePool Locked Liquidity", "HPLL") {
        HousePoolToken = housePoolToken;
    }

    function lockLiquidity(address receiver, address token, uint256 amount, uint256 duration) external returns(uint256) {       
        /*
        IERC20(token).transferFrom(msg.sender, receiver, amount);

        uint256 tokenId = _totalSupply;
        
        _lockedLiquidity[tokenId] = LockedLiquidity(token, amount, block.timestamp + duration);
        _totalSupply++;

        _safeMint(receiver, tokenId);

        if(PriceFeeds[token] != address(0)) {
            (,int256 answer,,,) = AggregatorV3Interface(PriceFeeds[token]).latestRoundData();
            if(answer > 0) {
                uint256 mintAmount = (amount * uint256(answer)) / (TOKEN_SCALE ** AggregatorV3Interface(PriceFeeds[token]).decimals());
                HousePoolToken.mint(receiver, mintAmount);
            }
        }

        return tokenId;
        */
    }

    function unlockLiquidity(uint256 tokenId, address receiver) external {
        /*
        require(_ownerOf(tokenId) == msg.sender);
        require(block.timestamp > _lockedLiquidity[tokenId].unlockTimestamp);

        IERC20(_lockedLiquidity[tokenId].token).transfer(receiver, _lockedLiquidity[tokenId].amount);
        */
    }
}