// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Base} from "./Base.t.sol";
import {ERC20Mock} from "./utils/ERC20Mock.sol";
import {FirewallVault} from "./utils/FirewallVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice End-to-end flows exercising a real ERC-4626 vault gated behind the firewall.
///         Covers the full deposit → share accrual → withdraw cycle, both via
///         watchtower approval and submitter-initiated pushThrough after the timelock.
contract IntegrationTest is Base {
    uint256 internal constant DEPOSIT = 1000e18;

    function setUp() public override {
        super.setUp();
        ERC20Mock(address(asset)).mint(alice, 10_000e18);
        ERC20Mock(address(asset)).mint(bob,   10_000e18);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    function _submitDeposit(address who, uint256 amount) internal returns (bytes32) {
        // User approves the firewall to pull tokens on their behalf at execution time.
        vm.prank(who);
        asset.approve(address(firewall), amount);
        return _submitWithToken(
            who,
            address(vault),
            address(asset),
            amount,
            abi.encodeCall(FirewallVault.deposit, (amount, who))
        );
    }

    function _submitWithdraw(address who, uint256 assets) internal returns (bytes32) {
        return _submit(
            who,
            address(vault),
            0,
            abi.encodeCall(FirewallVault.withdraw, (assets, who, who))
        );
    }

    function _submitRedeem(address who, uint256 shares) internal returns (bytes32) {
        return _submit(
            who,
            address(vault),
            0,
            abi.encodeCall(FirewallVault.redeem, (shares, who, who))
        );
    }

    // ── Deposit via watchtower approval ───────────────────────────────────────

    function test_deposit_approved_by_watchtower() public {
        bytes32 id = _submitDeposit(alice, DEPOSIT);
        _approve(id);

        assertEq(vault.balanceOf(alice), vault.convertToShares(DEPOSIT));
        assertEq(asset.balanceOf(alice), 10_000e18 - DEPOSIT);
    }

    function test_deposit_assets_held_in_vault() public {
        bytes32 id = _submitDeposit(alice, DEPOSIT);
        _approve(id);

        assertEq(asset.balanceOf(address(vault)), DEPOSIT);
        assertEq(vault.totalAssets(), DEPOSIT);
    }

    function test_firewall_holds_no_tokens_after_execution() public {
        bytes32 id = _submitDeposit(alice, DEPOSIT);
        _approve(id);

        assertEq(asset.balanceOf(address(firewall)), 0);
        assertEq(asset.allowance(address(firewall), address(vault)), 0);
    }

    // ── Withdraw via watchtower approval ──────────────────────────────────────

    function test_withdraw_approved_by_watchtower() public {
        bytes32 depositId = _submitDeposit(alice, DEPOSIT);
        _approve(depositId);

        vm.warp(block.timestamp + 1);
        bytes32 withdrawId = _submitWithdraw(alice, DEPOSIT / 2);
        _approve(withdrawId);

        assertEq(asset.balanceOf(alice), 10_000e18 - DEPOSIT / 2);
        assertEq(vault.totalAssets(), DEPOSIT / 2);
    }

    function test_redeem_approved_by_watchtower() public {
        bytes32 depositId = _submitDeposit(alice, DEPOSIT);
        _approve(depositId);

        uint256 shares = vault.balanceOf(alice);
        vm.warp(block.timestamp + 1);
        bytes32 redeemId = _submitRedeem(alice, shares);
        _approve(redeemId);

        assertEq(vault.balanceOf(alice), 0);
        assertEq(asset.balanceOf(alice), 10_000e18);
    }

    // ── Deposit via submitter pushThrough after timelock ──────────────────────

    function test_deposit_pushed_through_after_timelock() public {
        bytes32 id = _submitDeposit(alice, DEPOSIT);

        vm.warp(block.timestamp + TIMELOCK);
        vm.prank(alice);
        firewall.pushThrough(id);

        assertEq(vault.balanceOf(alice), vault.convertToShares(DEPOSIT));
    }

    // ── Direct vault calls are blocked ────────────────────────────────────────

    function test_direct_deposit_reverts() public {
        vm.startPrank(alice);
        asset.approve(address(vault), DEPOSIT);
        vm.expectRevert(abi.encodeWithSelector(FirewallVault.NotFirewall.selector, alice));
        vault.deposit(DEPOSIT, alice);
        vm.stopPrank();
    }

    function test_direct_withdraw_reverts() public {
        bytes32 id = _submitDeposit(alice, DEPOSIT);
        _approve(id);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(FirewallVault.NotFirewall.selector, alice));
        vault.withdraw(DEPOSIT, alice, alice);
    }

    function test_direct_redeem_reverts() public {
        bytes32 id = _submitDeposit(alice, DEPOSIT);
        _approve(id);

        uint256 shares = vault.balanceOf(alice);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(FirewallVault.NotFirewall.selector, alice));
        vault.redeem(shares, alice, alice);
    }

    // ── Multi-user isolation ──────────────────────────────────────────────────

    function test_alice_and_bob_independent_deposits() public {
        bytes32 aliceId = _submitDeposit(alice, 1000e18);
        vm.warp(block.timestamp + 1);
        bytes32 bobId   = _submitDeposit(bob,   2000e18);

        _approve(aliceId);
        _approve(bobId);

        assertEq(vault.maxWithdraw(alice), 1000e18);
        assertEq(vault.maxWithdraw(bob),   2000e18);
        assertEq(vault.totalAssets(), 3000e18);
    }

    function test_alice_approval_cannot_be_drained_by_bob_tx() public {
        // Alice approves firewall for 1000 and submits a deposit.
        bytes32 aliceId = _submitDeposit(alice, 1000e18);

        // Bob submits his own deposit — only his own approved amount should be pulled.
        vm.warp(block.timestamp + 1);
        bytes32 bobId = _submitDeposit(bob, 500e18);

        _approve(aliceId);
        _approve(bobId);

        // Alice lost exactly 1000, Bob lost exactly 500 — no cross-contamination.
        assertEq(asset.balanceOf(alice), 10_000e18 - 1000e18);
        assertEq(asset.balanceOf(bob),   10_000e18 - 500e18);
    }
}
