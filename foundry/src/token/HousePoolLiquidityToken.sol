// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/token/ERC20/IERC20.sol";

contract HousePoolLiquidityToken is ERC4626 {
    address public immutable housePool;

    constructor(string memory name, string memory symbol, address underlyingAsset, address housePoolContract) ERC20(name, symbol) ERC4626(IERC20(underlyingAsset)) {
        housePool = housePoolContract;
    }
    
    /**
     * @dev Deposit/mint common workflow.
     */
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal virtual override {
        // If _asset is ERC777, `transferFrom` can trigger a reentrancy BEFORE the transfer happens through the
        // `tokensToSend` hook. On the other hand, the `tokenReceived` hook, that is triggered after the transfer,
        // calls the vault, which is assumed not malicious.
        //
        // Conclusion: we need to do the transfer before we mint so that any reentrancy would happen before the
        // assets are transferred and before the shares are minted, which is a valid state.
        // slither-disable-next-line reentrancy-no-eth
        SafeERC20.safeTransferFrom(IERC20(asset()), caller, housePool, assets);
        _mint(receiver, shares);

        emit Deposit(caller, receiver, assets, shares);
    }

    /**
     * @dev Withdraw/redeem common workflow.
     */
    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares) internal virtual override {
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }

        // If _asset is ERC777, `transfer` can trigger a reentrancy AFTER the transfer happens through the
        // `tokensReceived` hook. On the other hand, the `tokensToSend` hook, that is triggered before the transfer,
        // calls the vault, which is assumed not malicious.
        //
        // Conclusion: we need to do the transfer after the burn so that any reentrancy would happen after the
        // shares are burned and after the assets are transferred, which is a valid state.
        _burn(owner, shares);
        SafeERC20.safeTransferFrom(IERC20(asset()), housePool, receiver, assets);

        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    function totalAssets() public view virtual override returns (uint256) {
        return IERC20(asset()).balanceOf(housePool);
    }

    function _decimalsOffset() internal view virtual override returns (uint8) {
        return 8;
    }
}