// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";
import { Vm }      from "forge-std/Vm.sol";

/**
 * @title  DeployConfig
 * @notice Generic, receiver-agnostic deployment config I/O.
 *
 * @dev Conventions:
 *      - The configuration is loaded from `script/config/<CONFIG>.json`. `CONFIG` may be
 *        provided via the `CONFIG` env var, otherwise it falls back to `<defaultSlug>`,
 *        which scripts compose from `<RECEIVER_TYPE>.<chainName>` so that the chain
 *        selected via `BaseDeployScript.selectChain()` automatically picks up the right
 *        config file (e.g. `arbitrum.plume.json`).
 *      - Chain selection (RPC + chainId resolution) is the responsibility of
 *        `BaseDeployScript`, not this library.
 *
 *      Per-receiver and executor-specific concerns live in their own libraries and are
 *      not meant to be edited when a new bridging solution is added.
 */
library DeployConfig {

    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    string internal constant CONFIG_DIR = "/script/config/";

    /**
     * @notice Loads the JSON config file for this deployment.
     * @param  defaultSlug Fallback file slug used when the `CONFIG` env var is unset.
     *                     Convention: `<receiver>.<chain>` (e.g. `arbitrum.arbitrum-one`).
     * @return config      The raw JSON payload as a string.
     */
    function loadConfig(string memory defaultSlug) internal returns (string memory config) {
        string memory configName = vm.envOr("CONFIG", string(""));
        if (bytes(configName).length == 0) {
            require(
                bytes(defaultSlug).length > 0,
                "DeployConfig/missing-CONFIG-and-no-default: set CONFIG=<slug> for script/config/<slug>.json"
            );
            configName = defaultSlug;
        }

        string memory configDir = string.concat(vm.projectRoot(), CONFIG_DIR);
        string memory path      = string.concat(configDir, configName, ".json");

        if (!vm.exists(path)) {
            console.log("DeployConfig: config slug not found ->", configName);
            console.log("DeployConfig: expected path         ->", path);
            console.log("DeployConfig: available configs in  ->", configDir);
            Vm.DirEntry[] memory entries = vm.readDir(configDir);
            for (uint256 i = 0; i < entries.length; i++) {
                console.log("  -", entries[i].path);
            }
            revert(string.concat("DeployConfig/config-not-found: ", configName, ".json"));
        }

        config = vm.readFile(path);
        console.log("DeployConfig: loaded", path);
    }

}
