// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import { DeployConfig } from "../deploy/DeployConfig.sol";

// Wrapper that re-exposes library functions externally so vm.expectRevert can observe reverts.
contract DeployConfigHarness {

    function loadConfig(string memory defaultSlug) external returns (string memory) {
        return DeployConfig.loadConfig(defaultSlug);
    }

}

contract DeployConfigTests is Test {

    DeployConfigHarness harness;

    function setUp() public {
        harness = new DeployConfigHarness();
    }

    // NOTE: vm.setEnv mutates a process-global env var, so all of the CONFIG cases are
    //       bundled sequentially in one test to avoid races with parallel runners.
    function test_loadConfig_envVarBehaviour() public {
        // 1. Empty CONFIG and empty defaultSlug -> dedicated revert.
        vm.setEnv("CONFIG", "");
        vm.expectRevert("DeployConfig/missing-CONFIG-and-no-default: set CONFIG=<slug> for script/config/<slug>.json");
        harness.loadConfig("");

        // 2. Empty CONFIG, defaultSlug points at non-existent file -> config-not-found.
        vm.setEnv("CONFIG", "");
        vm.expectRevert("DeployConfig/config-not-found: definitely-does-not-exist.json");
        harness.loadConfig("definitely-does-not-exist");

        // 3. Empty CONFIG, defaultSlug points at a real file -> loaded.
        vm.setEnv("CONFIG", "");
        string memory configFromDefault = harness.loadConfig("amb.example");
        assertTrue(bytes(configFromDefault).length > 0);

        // 4. Nonexistent CONFIG slug -> verbose output and config-not-found revert.
        vm.setEnv("CONFIG", "definitely-does-not-exist");
        vm.expectRevert("DeployConfig/config-not-found: definitely-does-not-exist.json");
        harness.loadConfig("amb.example");

        // 5. Valid CONFIG slug overrides defaultSlug.
        vm.setEnv("CONFIG", "amb.example");
        string memory configFromEnv = harness.loadConfig("does-not-matter");
        assertTrue(bytes(configFromEnv).length > 0);
    }

}
