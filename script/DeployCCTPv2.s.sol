// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";
import { Script }  from "forge-std/Script.sol";

import { CCTPv2Receiver } from "lib/xchain-helpers/src/receivers/CCTPv2Receiver.sol";

import { DeployConfig }        from "../deploy/DeployConfig.sol";
import { Verify }              from "../deploy/Verify.sol";
import { VerificationHelpers } from "../deploy/VerificationHelpers.sol";

import { Executor } from "src/Executor.sol";

/**
 * @notice Deploys an Executor and a CCTPv2Receiver on the chain reachable through `RPC_URL`.
 *
 * @dev Only CCTP v2 is supported. CCTP v1 is intentionally not used by these scripts.
 *
 *      Required env vars:
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
 *          "destinationMessenger": "0x...",  // CCTP v2 MessageTransmitter
 *          "sourceDomainId":       <uint32>,
 *          "sourceAuthority":      "0x..."
 *        }
 *      }
 */
contract DeployCCTPv2Full is Script {

    function run() public {
        DeployConfig.selectFork();

        string memory config = DeployConfig.loadConfig();

        DeployConfig.ExecutorParams     memory executorParams = DeployConfig.readExecutorParams(config);
        DeployConfig.CctpReceiverParams memory receiverParams = DeployConfig.readCctpReceiverParams(config);

        VerificationHelpers.validateExecutorParams(executorParams, false);
        VerificationHelpers.validateCctpReceiverParams(receiverParams);

        bytes32 sourceAuthorityBytes32 = bytes32(uint256(uint160(receiverParams.sourceAuthority)));

        vm.startBroadcast();

        Executor executor = new Executor(executorParams.delay, executorParams.gracePeriod);
        address  receiver = address(new CCTPv2Receiver({
            _destinationMessenger : receiverParams.destinationMessenger,
            _sourceDomainId       : receiverParams.sourceDomainId,
            _sourceAuthority      : sourceAuthorityBytes32,
            _target               : address(executor)
        }));

        executor.grantRole(executor.SUBMISSION_ROLE(),     receiver);
        executor.revokeRole(executor.DEFAULT_ADMIN_ROLE(), msg.sender);

        vm.stopBroadcast();

        console.log("executor deployed at:", address(executor));
        console.log("receiver deployed at:", receiver);

        Verify.verifyCctpV2Deployment({
            deployment : Verify.Deployment({
                executor : address(executor),
                receiver : receiver,
                deployer : msg.sender
            }),
            params : Verify.ExecutorParams({
                delay       : executorParams.delay,
                gracePeriod : executorParams.gracePeriod
            }),
            cctpV2MessageTransmitter : receiverParams.destinationMessenger,
            expectedSourceDomainId   : receiverParams.sourceDomainId,
            expectedSourceAuthority  : sourceAuthorityBytes32
        });
    }

}

/**
 * @notice Deploys a CCTPv2Receiver pointing at an already-deployed Executor.
 *
 * @dev Only CCTP v2 is supported. CCTP v1 is intentionally not used by these scripts.
 *
 *      Required env vars:
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
contract DeployCCTPv2ReceiverOnly is Script {

    function run() public {
        DeployConfig.selectFork();

        string memory config = DeployConfig.loadConfig();

        DeployConfig.ExecutorParams     memory executorParams = DeployConfig.readExecutorParams(config);
        DeployConfig.CctpReceiverParams memory receiverParams = DeployConfig.readCctpReceiverParams(config);

        VerificationHelpers.validateExecutorParams(executorParams, true);
        VerificationHelpers.validateCctpReceiverParams(receiverParams);

        address executor               = executorParams.existingAddress;
        bytes32 sourceAuthorityBytes32 = bytes32(uint256(uint160(receiverParams.sourceAuthority)));

        vm.startBroadcast();

        address receiver = address(new CCTPv2Receiver({
            _destinationMessenger : receiverParams.destinationMessenger,
            _sourceDomainId       : receiverParams.sourceDomainId,
            _sourceAuthority      : sourceAuthorityBytes32,
            _target               : executor
        }));

        vm.stopBroadcast();

        console.log("receiver deployed at:", receiver);
        console.log("re-using executor at :", executor);

        Verify.verifyCctpV2ReceiverDeployment({
            receiver                 : receiver,
            executor                 : executor,
            cctpV2MessageTransmitter : receiverParams.destinationMessenger,
            expectedSourceDomainId   : receiverParams.sourceDomainId,
            expectedSourceAuthority  : sourceAuthorityBytes32
        });
    }

}
