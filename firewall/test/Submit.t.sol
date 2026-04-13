// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Base} from "./Base.t.sol";
import {MoatFirewall} from "../src/MoatFirewall.sol";

contract SubmitTest is Base {
    bytes internal constant CALLDATA = abi.encodeWithSignature("foo()");

    // ── Happy path ────────────────────────────────────────────────────────────

    function test_submit_stores_transaction() public {
        bytes32 id = _submit(alice, address(mock), 0, CALLDATA);

        (
            address submitter,
            address target,
            uint256 value,
            ,
            uint256 submittedAt,
            MoatFirewall.Status status,
            ,

        ) = firewall.txs(id);

        assertEq(submitter,             alice);
        assertEq(target,                address(mock));
        assertEq(value,                 0);
        assertEq(submittedAt,           block.timestamp);
        assertEq(uint8(status),         uint8(MoatFirewall.Status.Pending));
    }

    function test_submit_stores_token_params() public {
        bytes32 id = _submitWithToken(alice, address(mock), address(asset), 500e18, CALLDATA);

        (, , , , , , address token, uint256 tokenAmount) = firewall.txs(id);

        assertEq(token,       address(asset));
        assertEq(tokenAmount, 500e18);
    }

    function test_submit_returns_correct_id() public {
        bytes32 expected = _id(alice, address(mock), CALLDATA, block.timestamp);
        bytes32 actual   = _submit(alice, address(mock), 0, CALLDATA);
        assertEq(actual, expected);
    }

    function test_submit_emits_queued_event() public {
        bytes32 expectedId = _id(alice, address(mock), CALLDATA, block.timestamp);

        vm.expectEmit(true, true, true, true);
        emit MoatFirewall.Queued(expectedId, alice, address(mock), 0, address(0), 0, CALLDATA);

        _submit(alice, address(mock), 0, CALLDATA);
    }

    function test_submit_with_eth_value() public {
        bytes32 id = _submit(alice, address(mock), 1 ether, "");
        (, , uint256 value, , , , , ) = firewall.txs(id);
        assertEq(value, 1 ether);
        assertEq(address(firewall).balance, 1 ether);
    }

    function test_submit_same_params_on_next_block_succeeds() public {
        _submit(alice, address(mock), 0, CALLDATA);
        vm.warp(block.timestamp + 1);
        _submit(alice, address(mock), 0, CALLDATA);
    }

    // ── Reverts ───────────────────────────────────────────────────────────────

    function test_submit_reverts_non_whitelisted_target() public {
        address unknown = makeAddr("unknown");
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MoatFirewall.TargetNotAllowed.selector, unknown));
        firewall.submit(unknown, 0, address(0), 0, CALLDATA);
    }

    function test_submit_reverts_value_mismatch() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MoatFirewall.ValueMismatch.selector, 0, 1 ether));
        firewall.submit(address(mock), 1 ether, address(0), 0, CALLDATA);
    }

    function test_submit_reverts_duplicate_in_same_block() public {
        bytes32 id = _submit(alice, address(mock), 0, CALLDATA);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MoatFirewall.DuplicateTransaction.selector, id));
        firewall.submit(address(mock), 0, address(0), 0, CALLDATA);
    }
}
