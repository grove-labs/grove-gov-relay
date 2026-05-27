// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";
import { Script }  from "forge-std/Script.sol";

import { OptimismReceiver } from "lib/xchain-helpers/src/receivers/OptimismReceiver.sol";

import { DeployConfig }           from "../deploy/DeployConfig.sol";
import { DeployExecutor }         from "../deploy/DeployExecutor.sol";
import { OptimismReceiverDeploy } from "../deploy/OptimismReceiverDeploy.sol";

import { Executor } from "src/Executor.sol";

/**
 * @notice Deploys an Executor and an OptimismReceiver on the chain reachable through `RPC_URL`.
 *
 * @dev Required env vars:
 *      - RPC_URL: RPC endpoint of the destination chain
 *      - CONFIG : config slug, file `script/config/<CONFIG>.json` must exist
 */
contract DeployOptimismFull is Script {

    function run() public {
        DeployConfig.selectFork();

        string memory config = DeployConfig.loadConfig();

        DeployExecutor.ExecutorParams   memory executorParams = DeployExecutor.readExecutorParams(config);
        OptimismReceiverDeploy.Params   memory receiverParams = OptimismReceiverDeploy.read(config);

        DeployExecutor.validateExecutorParams(executorParams, false);
        OptimismReceiverDeploy.validate(receiverParams);

        vm.startBroadcast();

        Executor executor = new Executor(executorParams.delay, executorParams.gracePeriod);
        address  receiver = address(new OptimismReceiver(receiverParams.sourceAuthority, address(executor)));

        DeployExecutor.setUpPermissions(executor, receiver, msg.sender);

        vm.stopBroadcast();

        console.log("executor deployed at:", address(executor));
        console.log("receiver deployed at:", receiver);

        OptimismReceiverDeploy.verifyFull({
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
 * @notice Deploys an OptimismReceiver pointing at an already-deployed Executor.
 *
 * @dev Required env vars:
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
contract DeployOptimismReceiverOnly is Script {

    function run() public {
        DeployConfig.selectFork();

        string memory config = DeployConfig.loadConfig();

        DeployExecutor.ExecutorParams   memory executorParams = DeployExecutor.readExecutorParams(config);
        OptimismReceiverDeploy.Params   memory receiverParams = OptimismReceiverDeploy.read(config);

        DeployExecutor.validateExecutorParams(executorParams, true);
        OptimismReceiverDeploy.validate(receiverParams);

        address executor = executorParams.existingAddress;

        vm.startBroadcast();

        address receiver = address(new OptimismReceiver(receiverParams.sourceAuthority, executor));

        vm.stopBroadcast();

        console.log("receiver deployed at:", receiver);
        console.log("re-using executor at :", executor);

        OptimismReceiverDeploy.verifyReceiverOnly({
            executor       : executor,
            receiver       : receiver,
            receiverParams : receiverParams
        });
    }

}
