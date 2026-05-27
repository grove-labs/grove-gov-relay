// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import { DeployConfig } from "../deploy/DeployConfig.sol";

// Wrapper that re-exposes library functions externally so vm.expectRevert can observe reverts.
contract DeployConfigHarness {

    function loadConfig() external returns (string memory) {
        return DeployConfig.loadConfig();
    }

}

contract DeployConfigTests is Test {

    DeployConfigHarness harness;

    function setUp() public {
        harness = new DeployConfigHarness();
    }

    // NOTE: vm.setEnv mutates a process-global env var, so this test bundles the three
    //       CONFIG cases sequentially in one test to avoid races with parallel runners.
    function test_loadConfig_envVarBehaviour() public {
        // 1. Empty CONFIG -> dedicated revert.
        vm.setEnv("CONFIG", "");
        vm.expectRevert("DeployConfig/missing-CONFIG-env-var: set CONFIG=<slug> for script/config/<slug>.json");
        harness.loadConfig();

        // 2. Nonexistent slug -> verbose output and config-not-found revert.
        vm.setEnv("CONFIG", "definitely-does-not-exist");
        vm.expectRevert("DeployConfig/config-not-found: definitely-does-not-exist.json");
        harness.loadConfig();

        // 3. Valid slug -> file is loaded, non-empty content returned.
        vm.setEnv("CONFIG", "amb.example");
        string memory config = harness.loadConfig();
        assertTrue(bytes(config).length > 0);
    }

}
