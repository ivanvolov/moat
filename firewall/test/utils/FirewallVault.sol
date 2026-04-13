// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice ERC-4626 tokenized vault whose entry points are gated behind the firewall.
///         The firewall handles token custody and approval — no overrides needed here.
contract FirewallVault is ERC4626 {
    address public immutable FIREWALL;

    error NotFirewall(address caller);

    modifier onlyFirewall() {
        if (msg.sender != FIREWALL) revert NotFirewall(msg.sender);
        _;
    }

    constructor(IERC20 asset, address firewall)
        ERC4626(asset)
        ERC20("Moat Vault Shares", "mvMOAT")
    {
        FIREWALL = firewall;
    }

    function deposit(uint256 assets, address receiver) public override onlyFirewall returns (uint256) {
        return super.deposit(assets, receiver);
    }

    function mint(uint256 shares, address receiver) public override onlyFirewall returns (uint256) {
        return super.mint(shares, receiver);
    }

    function withdraw(uint256 assets, address receiver, address owner) public override onlyFirewall returns (uint256) {
        return super.withdraw(assets, receiver, owner);
    }

    function redeem(uint256 shares, address receiver, address owner) public override onlyFirewall returns (uint256) {
        return super.redeem(shares, receiver, owner);
    }

    /// @dev The firewall already enforces that only the original submitter can
    ///      trigger a withdrawal, so no additional share allowance is required.
    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        override
    {
        _burn(owner, shares);
        SafeERC20.safeTransfer(IERC20(asset()), receiver, assets);
        emit Withdraw(caller, receiver, owner, assets, shares);
    }
}
