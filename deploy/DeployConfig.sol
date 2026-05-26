// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { Vm }      from "forge-std/Vm.sol";

import { LZReceiver } from "lib/xchain-helpers/src/receivers/LZReceiver.sol";

/**
 * @title  DeployConfig
 * @notice Helpers for loading deployment configuration from JSON and validating inputs.
 *
 * @dev Conventions:
 *      - The destination chain is selected via the `RPC_URL` environment variable; the
 *        operator is responsible for pairing the correct RPC with the chosen config.
 *      - The deployment configuration is loaded from `script/config/<CONFIG>.json`,
 *        where `<CONFIG>` is provided via the `CONFIG` environment variable.
 */
library DeployConfig {

    using stdJson for string;

    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    string internal constant CONFIG_DIR = "/script/config/";

    struct ExecutorParams {
        address existingAddress;
        uint256 delay;
        uint256 gracePeriod;
    }

    struct AMBReceiverParams {
        address amb;
        bytes32 sourceChainId;
        address sourceAuthority;
    }

    struct CctpReceiverParams {
        address destinationMessenger;
        uint32  sourceDomainId;
        address sourceAuthority;
    }

    struct LZReceiverParams {
        address                   destinationEndpoint;
        uint32                    srcEid;
        address                   sourceAuthority;
        address                   delegate;
        address                   owner;
        LZReceiver.UlConfigParams ulnConfig;
    }

    /**********************************************************************************************/
    /*** Loading                                                                                ***/
    /**********************************************************************************************/

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

    /**********************************************************************************************/
    /*** Readers                                                                                ***/
    /**********************************************************************************************/

    function readExecutorParams(string memory config)
        internal pure returns (ExecutorParams memory p)
    {
        p.existingAddress = config.readAddress(".executor.address");
        p.delay           = config.readUint(".executor.delay");
        p.gracePeriod     = config.readUint(".executor.gracePeriod");
    }

    function readAMBReceiverParams(string memory config)
        internal pure returns (AMBReceiverParams memory p)
    {
        p.amb             = config.readAddress(".receiver.amb");
        p.sourceChainId   = bytes32(config.readUint(".receiver.sourceChainId"));
        p.sourceAuthority = config.readAddress(".receiver.sourceAuthority");
    }

    function readSourceAuthority(string memory config)
        internal pure returns (address sourceAuthority)
    {
        sourceAuthority = config.readAddress(".receiver.sourceAuthority");
    }

    function readCctpReceiverParams(string memory config)
        internal pure returns (CctpReceiverParams memory p)
    {
        p.destinationMessenger = config.readAddress(".receiver.destinationMessenger");
        p.sourceDomainId       = uint32(config.readUint(".receiver.sourceDomainId"));
        p.sourceAuthority      = config.readAddress(".receiver.sourceAuthority");
    }

    function readLZReceiverParams(string memory config)
        internal pure returns (LZReceiverParams memory p)
    {
        p.destinationEndpoint = config.readAddress(".receiver.destinationEndpoint");
        p.srcEid              = uint32(config.readUint(".receiver.srcEid"));
        p.sourceAuthority     = config.readAddress(".receiver.sourceAuthority");
        p.delegate            = config.readAddress(".receiver.delegate");
        p.owner               = config.readAddress(".receiver.owner");

        p.ulnConfig = LZReceiver.UlConfigParams({
            confirmations        : uint32(config.readUint(".receiver.ulnConfig.confirmations")),
            requiredDVNs         : config.readAddressArray(".receiver.ulnConfig.requiredDVNs"),
            optionalDVNs         : config.readAddressArray(".receiver.ulnConfig.optionalDVNs"),
            optionalDVNThreshold : uint8(config.readUint(".receiver.ulnConfig.optionalDVNThreshold"))
        });
    }

}
