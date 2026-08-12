// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {MockERC20} from "../src/MockERC20.sol";
import {StakingVault} from "../src/StakingVault.sol";

contract DeployVault is Script {
    function run() external returns (MockERC20, StakingVault) {
        vm.startBroadcast();

        MockERC20 token = new MockERC20("Mock Staking Token", "MOCK");
        StakingVault vault = new StakingVault(token);

        vm.stopBroadcast();

        return (token, vault);
    }
}
