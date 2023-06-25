// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract HousePoolLockedLiquidity is ERC721 {
    struct LockedLiquidity {
        address token;
        uint256 amount;
        uint256 unlockTimestamp;
    }
    
    mapping(uint256 => LockedLiquidity) internal _lockedLiquidity;

    uint256 internal _totalSupply;

    address immutable public HousePoolToken;

    constructor(address housePoolToken) ERC721("HousePool Locked Liquidity", "HPLL") {
        HousePoolToken = housePoolToken;
    }

    function lockLiquidity(address receiver, address token, uint256 amount, uint256 duration) external returns(uint256 tokenId) {
        tokenId = _totalSupply;
        
        IERC20(token).transferFrom(_msgSender(), receiver, tokenId);

        _safeMint(receiver, tokenId);

        _lockedLiquidity[tokenId] = LockedLiquidity(token, amount, block.timestamp + duration);
        _totalSupply++;
    }

    function unlockLiquidity(uint256 tokenId, address receiver) external {
        require(_ownerOf(tokenId) == msg.sender);
        require(block.timestamp > _lockedLiquidity[tokenId].unlockTimestamp);

        IERC20(_lockedLiquidity[tokenId].token).transfer(receiver, _lockedLiquidity[tokenId].amount);
    }
}