// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Base} from "./Base.t.sol";
import {MoatFirewall} from "../src/MoatFirewall.sol";
import {ERC20Mock} from "./utils/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ApproveTest is Base {
    bytes internal constant CALLDATA = abi.encodeWithSignature("foo()");

    // ── Happy path ────────────────────────────────────────────────────────────

    function test_approve_executes_call() public {
        bytes32 id = _submit(alice, address(mock), 0, CALLDATA);
        _approve(id);
        assertEq(mock.callCount(), 1);
        assertEq(mock.lastCall().data, CALLDATA);
    }

    function test_approve_sets_status_executed() public {
        bytes32 id = _submit(alice, address(mock), 0, CALLDATA);
        _approve(id);
        assertEq(uint8(firewall.statusOf(id)), uint8(MoatFirewall.Status.Executed));
    }

    function test_approve_emits_executed_event() public {
        bytes32 id = _submit(alice, address(mock), 0, CALLDATA);

        vm.expectEmit(true, false, false, false);
        emit MoatFirewall.Executed(id);

        _approve(id);
    }

    function test_approve_forwards_eth() public {
        bytes32 id = _submit(alice, address(mock), 1 ether, "");
        uint256 before = address(mock).balance;
        _approve(id);
        assertEq(address(mock).balance, before + 1 ether);
        assertEq(address(firewall).balance, 0);
    }

    // ── Access control ────────────────────────────────────────────────────────

    function test_approve_reverts_for_non_watchtower() public {
        bytes32 id = _submit(alice, address(mock), 0, CALLDATA);
        vm.prank(stranger);
        vm.expectRevert(MoatFirewall.Unauthorized.selector);
        firewall.approve(id);
    }

    function test_approve_reverts_for_admin() public {
        bytes32 id = _submit(alice, address(mock), 0, CALLDATA);
        vm.prank(admin);
        vm.expectRevert(MoatFirewall.Unauthorized.selector);
        firewall.approve(id);
    }

    // ── Double-execution guard ────────────────────────────────────────────────

    function test_approve_reverts_if_already_executed() public {
        bytes32 id = _submit(alice, address(mock), 0, CALLDATA);
        _approve(id);

        vm.prank(watchtower);
        vm.expectRevert(abi.encodeWithSelector(MoatFirewall.NotPending.selector, id));
        firewall.approve(id);
    }

    // ── Token flow ───────────────────────────────────────────────────────────

    function test_approve_pulls_token_from_submitter() public {
        mock.setToken(address(asset));
        ERC20Mock(address(asset)).mint(alice, 500e18);
        vm.prank(alice);
        asset.approve(address(firewall), 500e18);

        bytes32 id = _submitWithToken(alice, address(mock), address(asset), 500e18, CALLDATA);
        _approve(id);

        assertEq(asset.balanceOf(alice), 0);
        assertEq(asset.balanceOf(address(mock)), 500e18);
    }

    function test_approve_resets_token_allowance_to_zero_after_execution() public {
        mock.setToken(address(asset));
        ERC20Mock(address(asset)).mint(alice, 500e18);
        vm.prank(alice);
        asset.approve(address(firewall), 500e18);

        bytes32 id = _submitWithToken(alice, address(mock), address(asset), 500e18, CALLDATA);
        _approve(id);

        assertEq(asset.allowance(address(firewall), address(mock)), 0);
    }

    function test_approve_reverts_if_submitter_lacks_token_balance() public {
        // alice has no tokens, submits anyway
        vm.prank(alice);
        asset.approve(address(firewall), 500e18);

        bytes32 id = _submitWithToken(alice, address(mock), address(asset), 500e18, CALLDATA);

        vm.prank(watchtower);
        vm.expectRevert();
        firewall.approve(id);
    }

    function test_approve_reverts_if_submitter_revoked_approval() public {
        ERC20Mock(address(asset)).mint(alice, 500e18);
        vm.prank(alice);
        asset.approve(address(firewall), 500e18);

        bytes32 id = _submitWithToken(alice, address(mock), address(asset), 500e18, CALLDATA);

        // alice revokes before watchtower acts
        vm.prank(alice);
        asset.approve(address(firewall), 0);

        vm.prank(watchtower);
        vm.expectRevert();
        firewall.approve(id);
    }

    // ── Call failure propagation ──────────────────────────────────────────────

    function test_approve_propagates_call_failure() public {
        mock.setShouldRevert(true, "nope");
        bytes32 id = _submit(alice, address(mock), 0, CALLDATA);

        vm.prank(watchtower);
        vm.expectRevert(abi.encodeWithSelector(MoatFirewall.CallFailed.selector, bytes(abi.encodeWithSignature("Error(string)", "nope"))));
        firewall.approve(id);
    }

    function test_approve_reverts_status_not_changed_on_call_failure() public {
        mock.setShouldRevert(true, "nope");
        bytes32 id = _submit(alice, address(mock), 0, CALLDATA);

        vm.prank(watchtower);
        try firewall.approve(id) {} catch {}

        // status must remain Pending since the whole tx reverted
        assertEq(uint8(firewall.statusOf(id)), uint8(MoatFirewall.Status.Pending));
    }
}
