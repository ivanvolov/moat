// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Base} from "./Base.t.sol";
import {MoatFirewall} from "../src/MoatFirewall.sol";
import {ERC20Mock} from "./utils/ERC20Mock.sol";

contract PushThroughTest is Base {
    bytes internal constant CALLDATA = abi.encodeWithSignature("foo()");

    // ── Happy path ────────────────────────────────────────────────────────────

    function test_pushThrough_executes_after_timelock() public {
        bytes32 id = _submit(alice, address(mock), 0, CALLDATA);
        vm.warp(block.timestamp + TIMELOCK);

        vm.prank(alice);
        firewall.pushThrough(id);

        assertEq(mock.callCount(), 1);
        assertEq(uint8(firewall.statusOf(id)), uint8(MoatFirewall.Status.Executed));
    }

    function test_pushThrough_emits_executed_event() public {
        bytes32 id = _submit(alice, address(mock), 0, CALLDATA);
        vm.warp(block.timestamp + TIMELOCK);

        vm.expectEmit(true, false, false, false);
        emit MoatFirewall.Executed(id);

        vm.prank(alice);
        firewall.pushThrough(id);
    }

    function test_pushThrough_forwards_eth() public {
        bytes32 id = _submit(alice, address(mock), 1 ether, "");
        vm.warp(block.timestamp + TIMELOCK);

        uint256 before = address(mock).balance;
        vm.prank(alice);
        firewall.pushThrough(id);

        assertEq(address(mock).balance, before + 1 ether);
        assertEq(address(firewall).balance, 0);
    }

    // ── Timelock enforcement ──────────────────────────────────────────────────

    function test_pushThrough_reverts_before_timelock_elapses() public {
        bytes32 id = _submit(alice, address(mock), 0, CALLDATA);
        uint256 unlocksAt = firewall.submittedAt(id) + TIMELOCK;

        vm.warp(block.timestamp + TIMELOCK - 1);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MoatFirewall.TimelockActive.selector, id, unlocksAt));
        firewall.pushThrough(id);
    }

    function test_pushThrough_reverts_immediately_after_submit() public {
        bytes32 id = _submit(alice, address(mock), 0, CALLDATA);
        uint256 unlocksAt = firewall.submittedAt(id) + TIMELOCK;

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MoatFirewall.TimelockActive.selector, id, unlocksAt));
        firewall.pushThrough(id);
    }

    // ── Submitter-only access ─────────────────────────────────────────────────

    function test_pushThrough_reverts_for_non_submitter() public {
        bytes32 id = _submit(alice, address(mock), 0, CALLDATA);
        vm.warp(block.timestamp + TIMELOCK);

        vm.prank(bob);
        vm.expectRevert(MoatFirewall.Unauthorized.selector);
        firewall.pushThrough(id);
    }

    function test_pushThrough_reverts_for_watchtower() public {
        bytes32 id = _submit(alice, address(mock), 0, CALLDATA);
        vm.warp(block.timestamp + TIMELOCK);

        vm.prank(watchtower);
        vm.expectRevert(MoatFirewall.Unauthorized.selector);
        firewall.pushThrough(id);
    }

    // ── Token flow ───────────────────────────────────────────────────────────

    function test_pushThrough_pulls_token_from_submitter() public {
        mock.setToken(address(asset));
        ERC20Mock(address(asset)).mint(alice, 500e18);
        vm.prank(alice);
        asset.approve(address(firewall), 500e18);

        bytes32 id = _submitWithToken(alice, address(mock), address(asset), 500e18, CALLDATA);
        vm.warp(block.timestamp + TIMELOCK);

        vm.prank(alice);
        firewall.pushThrough(id);

        assertEq(asset.balanceOf(alice), 0);
        assertEq(asset.balanceOf(address(mock)), 500e18);
    }

    function test_pushThrough_resets_token_allowance_to_zero() public {
        mock.setToken(address(asset));
        ERC20Mock(address(asset)).mint(alice, 500e18);
        vm.prank(alice);
        asset.approve(address(firewall), 500e18);

        bytes32 id = _submitWithToken(alice, address(mock), address(asset), 500e18, CALLDATA);
        vm.warp(block.timestamp + TIMELOCK);

        vm.prank(alice);
        firewall.pushThrough(id);

        assertEq(asset.allowance(address(firewall), address(mock)), 0);
    }

    function test_pushThrough_reverts_if_submitter_lacks_token_balance() public {
        vm.prank(alice);
        asset.approve(address(firewall), 500e18);

        bytes32 id = _submitWithToken(alice, address(mock), address(asset), 500e18, CALLDATA);
        vm.warp(block.timestamp + TIMELOCK);

        vm.prank(alice);
        vm.expectRevert();
        firewall.pushThrough(id);
    }

    // ── Already-executed guard ────────────────────────────────────────────────

    function test_pushThrough_reverts_if_already_approved() public {
        bytes32 id = _submit(alice, address(mock), 0, CALLDATA);
        _approve(id);

        vm.warp(block.timestamp + TIMELOCK);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MoatFirewall.NotPending.selector, id));
        firewall.pushThrough(id);
    }

    function test_pushThrough_reverts_if_already_pushed_through() public {
        bytes32 id = _submit(alice, address(mock), 0, CALLDATA);
        vm.warp(block.timestamp + TIMELOCK);

        vm.prank(alice);
        firewall.pushThrough(id);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MoatFirewall.NotPending.selector, id));
        firewall.pushThrough(id);
    }
}
