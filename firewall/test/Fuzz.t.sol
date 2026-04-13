// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Base} from "./Base.t.sol";
import {MoatFirewall} from "../src/MoatFirewall.sol";
import {ERC20Mock} from "./utils/ERC20Mock.sol";

contract FuzzTest is Base {
    // ── Submit ────────────────────────────────────────────────────────────────

    /// @dev Any ETH amount that alice has should be submittable and stored correctly.
    function testFuzz_submit_stores_correct_value(uint96 amount) public {
        vm.deal(alice, amount);
        bytes32 id = _submit(alice, address(mock), amount, "");
        (, , uint256 stored, , , , , ) = firewall.txs(id);
        assertEq(stored, amount);
        assertEq(address(firewall).balance, amount);
    }

    /// @dev Any calldata should be stored verbatim.
    function testFuzz_submit_stores_calldata(bytes calldata data) public {
        bytes32 id = _submit(alice, address(mock), 0, data);
        (, , , bytes memory stored, , , , ) = firewall.txs(id);
        assertEq(stored, data);
    }

    // ── PushThrough timelock ──────────────────────────────────────────────────

    /// @dev pushThrough must revert for any timestamp strictly before the unlock time.
    function testFuzz_pushThrough_reverts_before_unlock(uint32 elapsed) public {
        bytes32 id = _submit(alice, address(mock), 0, "");
        uint256 unlocksAt = firewall.submittedAt(id) + TIMELOCK;

        vm.assume(elapsed < TIMELOCK);
        vm.warp(block.timestamp + elapsed);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MoatFirewall.TimelockActive.selector, id, unlocksAt));
        firewall.pushThrough(id);
    }

    /// @dev pushThrough must succeed for any timestamp >= unlock time.
    function testFuzz_pushThrough_succeeds_after_unlock(uint32 extra) public {
        bytes32 id = _submit(alice, address(mock), 0, "");
        vm.warp(block.timestamp + TIMELOCK + extra);

        vm.prank(alice);
        firewall.pushThrough(id);

        assertEq(uint8(firewall.statusOf(id)), uint8(MoatFirewall.Status.Executed));
    }

    // ── Admin config ──────────────────────────────────────────────────────────

    /// @dev Any timelock duration set by admin should be applied to subsequent submissions.
    function testFuzz_timelock_duration_applied_to_new_submissions(uint32 duration) public {
        vm.assume(duration > 0);
        vm.prank(admin);
        firewall.setTimelockDuration(duration);

        bytes32 id = _submit(alice, address(mock), 0, "");
        uint256 unlocksAt = firewall.submittedAt(id) + duration;

        // one second before unlock must revert
        if (duration > 1) {
            vm.warp(block.timestamp + duration - 1);
            vm.prank(alice);
            vm.expectRevert(abi.encodeWithSelector(MoatFirewall.TimelockActive.selector, id, unlocksAt));
            firewall.pushThrough(id);
        }

        // at unlock must succeed
        vm.warp(block.timestamp + duration);
        vm.prank(alice);
        firewall.pushThrough(id);
    }

    // ── Token flow ───────────────────────────────────────────────────────────

    /// @dev Firewall pulls exactly the committed amount — no more, no less.
    function testFuzz_token_pull_is_exact(uint96 amount) public {
        vm.assume(amount > 0);
        mock.setToken(address(asset));
        ERC20Mock(address(asset)).mint(alice, amount);
        vm.prank(alice);
        asset.approve(address(firewall), amount);

        bytes32 id = _submitWithToken(alice, address(mock), address(asset), amount, "");
        _approve(id);

        assertEq(asset.balanceOf(alice), 0);
        assertEq(asset.balanceOf(address(mock)), amount);
        assertEq(asset.allowance(address(firewall), address(mock)), 0);
    }

    /// @dev Allowance on the firewall is always zero after execution regardless of amount.
    function testFuzz_firewall_allowance_always_zero_after_execution(uint96 amount) public {
        vm.assume(amount > 0);
        mock.setToken(address(asset));
        ERC20Mock(address(asset)).mint(alice, amount);
        vm.prank(alice);
        asset.approve(address(firewall), amount);

        bytes32 id = _submitWithToken(alice, address(mock), address(asset), amount, "");
        _approve(id);

        assertEq(asset.allowance(address(firewall), address(mock)), 0);
    }

    // ── Access control ────────────────────────────────────────────────────────

    /// @dev No arbitrary address can approve a transaction.
    function testFuzz_non_watchtower_cannot_approve(address caller) public {
        vm.assume(caller != watchtower);
        bytes32 id = _submit(alice, address(mock), 0, "");

        vm.prank(caller);
        vm.expectRevert(MoatFirewall.Unauthorized.selector);
        firewall.approve(id);
    }

    /// @dev No address other than the submitter can pushThrough.
    function testFuzz_non_submitter_cannot_push_through(address caller) public {
        vm.assume(caller != alice);
        bytes32 id = _submit(alice, address(mock), 0, "");
        vm.warp(block.timestamp + TIMELOCK);

        vm.prank(caller);
        vm.expectRevert(MoatFirewall.Unauthorized.selector);
        firewall.pushThrough(id);
    }
}
