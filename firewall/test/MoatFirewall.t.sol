// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MoatFirewall} from "../src/MoatFirewall.sol";

// ── Minimal vault used only in tests ─────────────────────────────────────────

contract Vault {
    address public immutable FIREWALL;
    mapping(address => uint256) public balances;

    error DirectCall();

    constructor(address firewall) { FIREWALL = firewall; }

    modifier onlyFirewall() {
        if (msg.sender != FIREWALL) revert DirectCall();
        _;
    }

    function deposit() external payable onlyFirewall {
        balances[MoatFirewall(msg.sender).currentUser()] += msg.value;
    }

    function withdraw(uint256 amount) external onlyFirewall {
        address user = MoatFirewall(msg.sender).currentUser();
        balances[user] -= amount;
        (bool ok,) = user.call{value: amount}("");
        require(ok);
    }

    receive() external payable {}
}

// ─────────────────────────────────────────────────────────────────────────────

contract MoatFirewallTest is Test {
    MoatFirewall fw;
    Vault        vault;

    address admin      = makeAddr("admin");
    address watchtower = makeAddr("watchtower");
    address user       = makeAddr("user");
    address rando      = makeAddr("rando");

    uint256 constant DELAY = 30 minutes;

    function setUp() public {
        fw    = new MoatFirewall(admin, watchtower, DELAY);
        vault = new Vault(address(fw));
        vm.prank(admin); fw.allow(address(vault));
        vm.deal(user, 100 ether);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    function _deposit(uint256 amt) internal returns (bytes32) {
        vm.prank(user);
        return fw.submit{value: amt}(address(vault), amt, abi.encodeCall(Vault.deposit, ()));
    }

    function _withdraw(uint256 amt) internal returns (bytes32) {
        vm.prank(user);
        return fw.submit(address(vault), 0, abi.encodeCall(Vault.withdraw, (amt)));
    }

    // ── Happy path ────────────────────────────────────────────────────────────

    function test_approve_executes() public {
        bytes32 id = _deposit(1 ether);
        vm.prank(watchtower);
        fw.approve(id);
        assertEq(vault.balances(user), 1 ether);
        assertEq(uint8(fw.statusOf(id)), uint8(MoatFirewall.Status.Executed));
    }

    function test_deposit_then_withdraw() public {
        bytes32 depId = _deposit(5 ether);
        vm.prank(watchtower); fw.approve(depId);

        bytes32 wdId = _withdraw(3 ether);
        vm.prank(watchtower); fw.approve(wdId);

        assertEq(vault.balances(user), 2 ether);
    }

    // ── Reject → pushThrough ─────────────────────────────────────────────────

    function test_reject_then_pushThrough_after_delay() public {
        bytes32 id = _deposit(2 ether);

        vm.prank(watchtower);
        fw.reject(id, "suspicious");

        vm.expectRevert();
        fw.pushThrough(id); // too early

        vm.warp(block.timestamp + DELAY + 1);
        fw.pushThrough(id);
        assertEq(vault.balances(user), 2 ether);
    }

    // ── Pending → pushThrough after delay (no watchtower response) ────────────

    function test_pushThrough_pending_after_delay() public {
        bytes32 id = _deposit(3 ether);
        vm.warp(block.timestamp + DELAY + 1);
        fw.pushThrough(id);
        assertEq(vault.balances(user), 3 ether);
    }

    // ── Cannot pushThrough before delay ──────────────────────────────────────

    function test_pushThrough_reverts_before_delay() public {
        bytes32 id = _deposit(1 ether);
        vm.warp(block.timestamp + DELAY - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                MoatFirewall.TimelockActive.selector,
                id,
                fw.submittedAt(id) + DELAY
            )
        );
        fw.pushThrough(id);
    }

    // ── Cannot execute already-executed tx ───────────────────────────────────

    function test_cannot_approve_twice() public {
        bytes32 id = _deposit(1 ether);
        vm.startPrank(watchtower);
        fw.approve(id);
        vm.expectRevert(abi.encodeWithSelector(MoatFirewall.NotPending.selector, id));
        fw.approve(id);
        vm.stopPrank();
    }

    function test_cannot_pushThrough_executed() public {
        bytes32 id = _deposit(1 ether);
        vm.prank(watchtower); fw.approve(id);
        vm.warp(block.timestamp + DELAY + 1);
        vm.expectRevert(abi.encodeWithSelector(MoatFirewall.NotPending.selector, id));
        fw.pushThrough(id);
    }

    // ── Access control ────────────────────────────────────────────────────────

    function test_rando_cannot_approve() public {
        bytes32 id = _deposit(1 ether);
        vm.prank(rando);
        vm.expectRevert(MoatFirewall.Unauthorized.selector);
        fw.approve(id);
    }

    function test_rando_cannot_reject() public {
        bytes32 id = _deposit(1 ether);
        vm.prank(rando);
        vm.expectRevert(MoatFirewall.Unauthorized.selector);
        fw.reject(id, "nope");
    }

    function test_rando_cannot_set_watchtower() public {
        vm.prank(rando);
        vm.expectRevert(MoatFirewall.Unauthorized.selector);
        fw.setWatchtower(rando);
    }

    function test_rando_cannot_set_timelock() public {
        vm.prank(rando);
        vm.expectRevert(MoatFirewall.Unauthorized.selector);
        fw.setTimelockDuration(1 hours);
    }

    // ── Admin config ──────────────────────────────────────────────────────────

    function test_admin_sets_watchtower() public {
        address newWt = makeAddr("newWt");
        vm.prank(admin); fw.setWatchtower(newWt);
        assertEq(fw.watchtower(), newWt);
    }

    function test_admin_sets_timelock() public {
        vm.prank(admin); fw.setTimelockDuration(1 hours);
        assertEq(fw.timelockDuration(), 1 hours);
    }

    function test_admin_transfers_admin() public {
        vm.prank(admin); fw.setAdmin(rando);
        assertEq(fw.admin(), rando);
        // original admin is now locked out
        vm.prank(admin);
        vm.expectRevert(MoatFirewall.Unauthorized.selector);
        fw.setWatchtower(admin);
    }

    // ── Vault rejects direct calls ────────────────────────────────────────────

    function test_vault_rejects_direct_deposit() public {
        vm.prank(user);
        vm.expectRevert(Vault.DirectCall.selector);
        vault.deposit{value: 1 ether}();
    }

    function test_vault_rejects_direct_withdraw() public {
        vm.prank(user);
        vm.expectRevert(Vault.DirectCall.selector);
        vault.withdraw(1 ether);
    }

    // ── Whitelist ─────────────────────────────────────────────────────────────

    function test_submit_reverts_for_non_whitelisted_target() public {
        address unknown = makeAddr("unknown");
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(MoatFirewall.TargetNotAllowed.selector, unknown));
        fw.submit(unknown, 0, "");
    }

    function test_admin_can_disallow_target() public {
        vm.prank(admin); fw.disallow(address(vault));
        assertFalse(fw.whitelist(address(vault)));

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(MoatFirewall.TargetNotAllowed.selector, address(vault)));
        fw.submit(address(vault), 0, abi.encodeCall(Vault.deposit, ()));
    }

    function test_rando_cannot_allow_target() public {
        vm.prank(rando);
        vm.expectRevert(MoatFirewall.Unauthorized.selector);
        fw.allow(makeAddr("x"));
    }

    function test_rando_cannot_disallow_target() public {
        vm.prank(rando);
        vm.expectRevert(MoatFirewall.Unauthorized.selector);
        fw.disallow(address(vault));
    }

    // ── ETH refund on rejection ───────────────────────────────────────────────

    function test_reject_refunds_eth_on_pushThrough() public {
        bytes32 id = _deposit(1 ether);
        vm.prank(watchtower); fw.reject(id, "blocked");

        uint256 before = user.balance;
        vm.warp(block.timestamp + DELAY + 1);
        fw.pushThrough(id);

        // vault credited, ETH flowed from firewall → vault correctly
        assertEq(vault.balances(user), 1 ether);
        assertEq(user.balance, before); // user paid 1 eth, now it's in the vault
    }
}
