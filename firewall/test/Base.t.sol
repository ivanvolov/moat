// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MoatFirewall} from "../src/MoatFirewall.sol";
import {MockTarget} from "./utils/MockTarget.sol";
import {FirewallVault} from "./utils/FirewallVault.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Mock} from "./utils/ERC20Mock.sol";

abstract contract Base is Test {
    // ── Constants ────────────────────────────────────────────────────────────

    uint256 internal constant TIMELOCK = 1 hours;

    // ── Actors ───────────────────────────────────────────────────────────────

    address internal admin      = makeAddr("admin");
    address internal watchtower = makeAddr("watchtower");
    address internal alice      = makeAddr("alice");
    address internal bob        = makeAddr("bob");
    address internal stranger   = makeAddr("stranger");

    // ── Contracts ────────────────────────────────────────────────────────────

    MoatFirewall  internal firewall;
    MockTarget    internal mock;
    ERC20         internal asset;
    FirewallVault internal vault;

    // ── Setup ────────────────────────────────────────────────────────────────

    function setUp() public virtual {
        firewall = new MoatFirewall(admin, watchtower, TIMELOCK);
        mock     = new MockTarget();
        asset    = new ERC20Mock("Mock USD", "mUSD");
        vault    = new FirewallVault(asset, address(firewall));

        vm.startPrank(admin);
        firewall.allow(address(mock));
        firewall.allow(address(vault));
        vm.stopPrank();

        vm.deal(alice, 100 ether);
        vm.deal(bob,   100 ether);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    /// @dev Submit with no token transfer.
    function _submit(address submitter, address target, uint256 value, bytes memory data)
        internal
        returns (bytes32 id)
    {
        vm.prank(submitter);
        id = firewall.submit{value: value}(target, value, address(0), 0, data);
    }

    /// @dev Submit with an ERC-20 token transfer.
    function _submitWithToken(
        address submitter,
        address target,
        address token,
        uint256 tokenAmount,
        bytes memory data
    ) internal returns (bytes32 id) {
        vm.prank(submitter);
        id = firewall.submit(target, 0, token, tokenAmount, data);
    }

    function _id(address submitter, address target, bytes memory data, uint256 timestamp)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(submitter, target, data, timestamp));
    }

    function _approve(bytes32 id) internal {
        vm.prank(watchtower);
        firewall.approve(id);
    }
}
