// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";
import { Script }  from "forge-std/Script.sol";

import { LZReceiver } from "lib/xchain-helpers/src/receivers/LZReceiver.sol";

import { DeployConfig }        from "../deploy/DeployConfig.sol";
import { Verify }              from "../deploy/Verify.sol";
import { VerificationHelpers } from "../deploy/VerificationHelpers.sol";

import { Executor } from "src/Executor.sol";

/**
 * @notice Deploys an Executor and an LZReceiver on the chain reachable through `RPC_URL`.
 *
 * @dev Required env vars:
 *      - RPC_URL: RPC endpoint of the destination chain
 *      - CONFIG : config slug, file `script/config/<CONFIG>.json` must exist
 *
 *      JSON schema:
 *      {
 *        "executor": {
 *          "address":     "0x0000...0000",   // must be unset for full deploy
 *          "delay":       <uint>,
 *          "gracePeriod": <uint>
 *        },
 *        "receiver": {
 *          "destinationEndpoint": "0x...",
 *          "srcEid":              <uint32>,
 *          "sourceAuthority":     "0x...",
 *          "delegate":            "0x...",
 *          "owner":               "0x...",
 *          "ulnConfig": {
 *            "confirmations":        <uint32>,
 *            "requiredDVNs":         ["0x..."],
 *            "optionalDVNs":         [],
 *            "optionalDVNThreshold": <uint8>
 *          }
 *        }
 *      }
 */
contract DeployLZFull is Script {

    function run() public {
        DeployConfig.selectFork();

        string memory config = DeployConfig.loadConfig();

        DeployConfig.ExecutorParams   memory executorParams = DeployConfig.readExecutorParams(config);
        DeployConfig.LZReceiverParams memory receiverParams = DeployConfig.readLZReceiverParams(config);

        VerificationHelpers.validateExecutorParams(executorParams, false);
        VerificationHelpers.validateLZReceiverParams(receiverParams);

        bytes32 sourceAuthorityBytes32 = bytes32(uint256(uint160(receiverParams.sourceAuthority)));

        vm.startBroadcast();

        Executor executor = new Executor(executorParams.delay, executorParams.gracePeriod);
        address  receiver = address(new LZReceiver({
            _destinationEndpoint : receiverParams.destinationEndpoint,
            _srcEid              : receiverParams.srcEid,
            _sourceAuthority     : sourceAuthorityBytes32,
            _target              : address(executor),
            _delegate            : receiverParams.delegate,
            _owner               : receiverParams.owner,
            _ulnConfigParams     : receiverParams.ulnConfig
        }));

        executor.grantRole(executor.SUBMISSION_ROLE(),     receiver);
        executor.revokeRole(executor.DEFAULT_ADMIN_ROLE(), msg.sender);

        vm.stopBroadcast();

        console.log("executor deployed at:", address(executor));
        console.log("receiver deployed at:", receiver);

        Verify.verifyLayerZeroDeployment({
            deployment : Verify.Deployment({
                executor : address(executor),
                receiver : receiver,
                deployer : msg.sender
            }),
            params : Verify.ExecutorParams({
                delay       : executorParams.delay,
                gracePeriod : executorParams.gracePeriod
            }),
            endpoint                : receiverParams.destinationEndpoint,
            expectedSrcEid          : receiverParams.srcEid,
            expectedSourceAuthority : sourceAuthorityBytes32,
            expectedDelegate        : receiverParams.delegate,
            expectedOwner           : receiverParams.owner,
            ulnConfigParams         : receiverParams.ulnConfig
        });
    }

}

/**
 * @notice Deploys an LZReceiver pointing at an already-deployed Executor.
 *
 * @dev Required env vars:
 *      - RPC_URL: RPC endpoint of the destination chain
 *      - CONFIG : config slug, file `script/config/<CONFIG>.json` must exist
 *
 *      `executor.address` in the JSON config must be the address of the already-deployed
 *      executor on the destination chain.
 *
 *      Note: this script does NOT call setUpExecutorPermissions - granting the new receiver
 *      its SUBMISSION_ROLE on the existing executor must be done via a governance payload,
 *      since the deployer no longer holds DEFAULT_ADMIN_ROLE on the executor after the
 *      original deployment.
 */
contract DeployLZReceiverOnly is Script {

    function run() public {
        DeployConfig.selectFork();

        string memory config = DeployConfig.loadConfig();

        DeployConfig.ExecutorParams   memory executorParams = DeployConfig.readExecutorParams(config);
        DeployConfig.LZReceiverParams memory receiverParams = DeployConfig.readLZReceiverParams(config);

        VerificationHelpers.validateExecutorParams(executorParams, true);
        VerificationHelpers.validateLZReceiverParams(receiverParams);

        address executor               = executorParams.existingAddress;
        bytes32 sourceAuthorityBytes32 = bytes32(uint256(uint160(receiverParams.sourceAuthority)));

        vm.startBroadcast();

        address receiver = address(new LZReceiver({
            _destinationEndpoint : receiverParams.destinationEndpoint,
            _srcEid              : receiverParams.srcEid,
            _sourceAuthority     : sourceAuthorityBytes32,
            _target              : executor,
            _delegate            : receiverParams.delegate,
            _owner               : receiverParams.owner,
            _ulnConfigParams     : receiverParams.ulnConfig
        }));

        vm.stopBroadcast();

        console.log("receiver deployed at:", receiver);
        console.log("re-using executor at :", executor);

        Verify.verifyLayerZeroReceiverOnly({
            receiver                : receiver,
            executor                : executor,
            endpoint                : receiverParams.destinationEndpoint,
            expectedSrcEid          : receiverParams.srcEid,
            expectedSourceAuthority : sourceAuthorityBytes32,
            expectedDelegate        : receiverParams.delegate,
            expectedOwner           : receiverParams.owner,
            ulnConfigParams         : receiverParams.ulnConfig
        });
    }

}
