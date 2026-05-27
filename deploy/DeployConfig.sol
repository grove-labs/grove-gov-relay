// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";
import { Vm }      from "forge-std/Vm.sol";

/**
 * @title  DeployConfig
 * @notice Generic, receiver-agnostic deployment I/O: loading config files and selecting the
 *         destination chain via RPC.
 *
 * @dev Conventions:
 *      - The destination chain is selected via the `RPC_URL` environment variable; the
 *        operator is responsible for pairing the correct RPC with the chosen config.
 *      - The deployment configuration is loaded from `script/config/<CONFIG>.json`,
 *        where `<CONFIG>` is provided via the `CONFIG` environment variable.
 *
 *      Per-receiver and executor-specific concerns live in their own libraries and are not
 *      meant to be edited when a new bridging solution is added.
 */
library DeployConfig {

    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    string internal constant CONFIG_DIR = "/script/config/";

    function loadConfig() internal returns (string memory config) {
        string memory configName = vm.envOr("CONFIG", string(""));
        require(
            bytes(configName).length > 0,
            "DeployConfig/missing-CONFIG-env-var: set CONFIG=<slug> for script/config/<slug>.json"
        );

        string memory configDir = string.concat(vm.projectRoot(), CONFIG_DIR);
        string memory path      = string.concat(configDir, configName, ".json");

        if (!vm.exists(path)) {
            console.log("DeployConfig: config slug not found ->", configName);
            console.log("DeployConfig: expected path           ->", path);
            console.log("DeployConfig: available configs in    ->", configDir);
            Vm.DirEntry[] memory entries = vm.readDir(configDir);
            for (uint256 i = 0; i < entries.length; i++) {
                console.log("  -", entries[i].path);
            }
            revert(string.concat("DeployConfig/config-not-found: ", configName, ".json"));
        }

        config = vm.readFile(path);
        console.log("DeployConfig: loaded", path);
    }

    /**
     * @dev Creates an in-memory fork against `RPC_URL` so that storage reads, code probes,
     *      and `block.chainid` reflect the destination chain during script execution.
     *
     *      For broadcasting, `forge script` itself also needs `--rpc-url $RPC_URL` (passed
     *      via the Makefile recipes); the `--rpc-url` flag controls where forge actually
     *      sends signed transactions and how it estimates gas. Both settings should point
     *      to the same endpoint - the in-script fork is for simulation/validation, the
     *      forge-level RPC is for the broadcast leg.
     */
    function selectFork() internal returns (uint256 forkId) {
        string memory rpcUrl = vm.envOr("RPC_URL", string(""));
        require(
            bytes(rpcUrl).length > 0,
            "DeployConfig/missing-RPC_URL-env-var: set RPC_URL=<endpoint> to select destination chain"
        );
        forkId = vm.createSelectFork(rpcUrl);
    }

}
