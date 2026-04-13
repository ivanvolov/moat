// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Base} from "./Base.t.sol";
import {MoatFirewall} from "../src/MoatFirewall.sol";

contract AdminTest is Base {
    // ── Whitelist ─────────────────────────────────────────────────────────────

    function test_allow_adds_to_whitelist() public {
        address target = makeAddr("target");
        vm.prank(admin);
        firewall.allow(target);
        assertTrue(firewall.whitelist(target));
    }

    function test_allow_emits_target_set() public {
        address target = makeAddr("target");
        vm.expectEmit(true, false, false, true);
        emit MoatFirewall.TargetSet(target, true);
        vm.prank(admin);
        firewall.allow(target);
    }

    function test_disallow_removes_from_whitelist() public {
        vm.prank(admin);
        firewall.disallow(address(mock));
        assertFalse(firewall.whitelist(address(mock)));
    }

    function test_disallow_emits_target_set() public {
        vm.expectEmit(true, false, false, true);
        emit MoatFirewall.TargetSet(address(mock), false);
        vm.prank(admin);
        firewall.disallow(address(mock));
    }

    function test_disallow_prevents_new_submissions() public {
        vm.prank(admin);
        firewall.disallow(address(mock));

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MoatFirewall.TargetNotAllowed.selector, address(mock)));
        firewall.submit(address(mock), 0, address(0), 0, "");
    }

    function test_allow_reverts_for_non_admin() public {
        vm.prank(stranger);
        vm.expectRevert(MoatFirewall.Unauthorized.selector);
        firewall.allow(makeAddr("x"));
    }

    function test_disallow_reverts_for_non_admin() public {
        vm.prank(stranger);
        vm.expectRevert(MoatFirewall.Unauthorized.selector);
        firewall.disallow(address(mock));
    }

    // ── setWatchtower ─────────────────────────────────────────────────────────

    function test_set_watchtower_updates_address() public {
        address newWt = makeAddr("newWt");
        vm.prank(admin);
        firewall.setWatchtower(newWt);
        assertEq(firewall.watchtower(), newWt);
    }

    function test_set_watchtower_reverts_for_non_admin() public {
        vm.prank(stranger);
        vm.expectRevert(MoatFirewall.Unauthorized.selector);
        firewall.setWatchtower(stranger);
    }

    function test_old_watchtower_cannot_approve_after_replacement() public {
        address newWt = makeAddr("newWt");
        vm.prank(admin);
        firewall.setWatchtower(newWt);

        bytes32 id = _submit(alice, address(mock), 0, "");

        vm.prank(watchtower); // old watchtower
        vm.expectRevert(MoatFirewall.Unauthorized.selector);
        firewall.approve(id);
    }

    // ── setTimelockDuration ───────────────────────────────────────────────────

    function test_set_timelock_duration_updates_value() public {
        vm.prank(admin);
        firewall.setTimelockDuration(2 hours);
        assertEq(firewall.timelockDuration(), 2 hours);
    }

    function test_set_timelock_duration_reverts_for_non_admin() public {
        vm.prank(stranger);
        vm.expectRevert(MoatFirewall.Unauthorized.selector);
        firewall.setTimelockDuration(2 hours);
    }

    function test_new_timelock_applies_to_future_submissions() public {
        vm.prank(admin);
        firewall.setTimelockDuration(2 hours);

        bytes32 id = _submit(alice, address(mock), 0, "");
        uint256 unlocksAt = firewall.submittedAt(id) + 2 hours;

        // 1 hour is not enough anymore
        vm.warp(block.timestamp + 1 hours);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MoatFirewall.TimelockActive.selector, id, unlocksAt));
        firewall.pushThrough(id);
    }

    // ── setAdmin ──────────────────────────────────────────────────────────────

    function test_set_admin_transfers_role() public {
        vm.prank(admin);
        firewall.setAdmin(bob);
        assertEq(firewall.admin(), bob);
    }

    function test_set_admin_locks_out_old_admin() public {
        vm.prank(admin);
        firewall.setAdmin(bob);

        vm.prank(admin); // old admin
        vm.expectRevert(MoatFirewall.Unauthorized.selector);
        firewall.setWatchtower(admin);
    }

    function test_set_admin_reverts_for_non_admin() public {
        vm.prank(stranger);
        vm.expectRevert(MoatFirewall.Unauthorized.selector);
        firewall.setAdmin(stranger);
    }
}
