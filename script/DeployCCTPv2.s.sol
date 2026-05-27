// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";
import { Script }  from "forge-std/Script.sol";

import { CCTPv2Receiver } from "lib/xchain-helpers/src/receivers/CCTPv2Receiver.sol";

import { CCTPv2ReceiverDeploy } from "../deploy/CCTPv2ReceiverDeploy.sol";
import { DeployConfig }         from "../deploy/DeployConfig.sol";
import { DeployExecutor }       from "../deploy/DeployExecutor.sol";

import { Executor } from "src/Executor.sol";

/**
 * @notice Deploys an Executor and a CCTPv2Receiver on the chain reachable through `RPC_URL`.
 *
 * @dev Only CCTP v2 is supported. CCTP v1 is intentionally not used by these scripts.
 *
 *      Required env vars:
 *      - RPC_URL: RPC endpoint of the destination chain
 *      - CONFIG : config slug, file `script/config/<CONFIG>.json` must exist
 */
contract DeployCCTPv2Full is Script {

    function run() public {
        DeployConfig.selectFork();

        string memory config = DeployConfig.loadConfig();

        DeployExecutor.ExecutorParams memory executorParams = DeployExecutor.readExecutorParams(config);
        CCTPv2ReceiverDeploy.Params   memory receiverParams = CCTPv2ReceiverDeploy.read(config);

        DeployExecutor.validateExecutorParams(executorParams, false);
        CCTPv2ReceiverDeploy.validate(receiverParams);

        bytes32 sourceAuthorityBytes32 = bytes32(uint256(uint160(receiverParams.sourceAuthority)));

        vm.startBroadcast();

        Executor executor = new Executor(executorParams.delay, executorParams.gracePeriod);
        address  receiver = address(new CCTPv2Receiver({
            _destinationMessenger : receiverParams.destinationMessenger,
            _sourceDomainId       : receiverParams.sourceDomainId,
            _sourceAuthority      : sourceAuthorityBytes32,
            _target               : address(executor)
        }));

        DeployExecutor.setUpPermissions(executor, receiver, msg.sender);

        vm.stopBroadcast();

        console.log("executor deployed at:", address(executor));
        console.log("receiver deployed at:", receiver);

        CCTPv2ReceiverDeploy.verifyFull({
            deployment : DeployExecutor.Deployment({
                executor : address(executor),
                receiver : receiver,
                deployer : msg.sender
            }),
            executorParams : executorParams,
            receiverParams : receiverParams
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
 *      Note: this script does NOT call setUpPermissions - granting the new receiver its
 *      SUBMISSION_ROLE on the existing executor must be done via a governance payload,
 *      since the deployer no longer holds DEFAULT_ADMIN_ROLE on the executor after the
 *      original deployment.
 */
contract DeployCCTPv2ReceiverOnly is Script {

    function run() public {
        DeployConfig.selectFork();

        string memory config = DeployConfig.loadConfig();

        DeployExecutor.ExecutorParams memory executorParams = DeployExecutor.readExecutorParams(config);
        CCTPv2ReceiverDeploy.Params   memory receiverParams = CCTPv2ReceiverDeploy.read(config);

        DeployExecutor.validateExecutorParams(executorParams, true);
        CCTPv2ReceiverDeploy.validate(receiverParams);

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

        CCTPv2ReceiverDeploy.verifyReceiverOnly({
            executor       : executor,
            receiver       : receiver,
            receiverParams : receiverParams
        });
    }

}
