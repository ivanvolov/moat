// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {MoatFirewall} from "../src/MoatFirewall.sol";

/// @notice Deploys MoatFirewall.
///
/// Required env vars:
///   ADMIN              — address that can manage the whitelist and roles
///   WATCHTOWER         — address authorized to approve pending transactions
///   TIMELOCK_DURATION  — seconds after which the submitter can pushThrough
///
/// Usage:
///   forge script script/Deploy.s.sol:Deploy \
///     --rpc-url $RPC_URL \
///     --private-key $PRIVATE_KEY \
///     --broadcast \
///     --verify
contract Deploy is Script {
    function run() external returns (MoatFirewall firewall) {
        address admin          = vm.envAddress("ADMIN");
        address watchtower     = vm.envAddress("WATCHTOWER");
        uint256 timelock       = vm.envUint("TIMELOCK_DURATION");

        vm.startBroadcast();
        firewall = new MoatFirewall(admin, watchtower, timelock);
        vm.stopBroadcast();

        console2.log("MoatFirewall deployed at:", address(firewall));
        console2.log("  admin:             ", admin);
        console2.log("  watchtower:        ", watchtower);
        console2.log("  timelockDuration:  ", timelock);
    }
}
