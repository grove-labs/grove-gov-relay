// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";

import { OptimismReceiver } from "lib/xchain-helpers/src/receivers/OptimismReceiver.sol";

import { DeployConfig }           from "../deploy/DeployConfig.sol";
import { DeployExecutor }         from "../deploy/DeployExecutor.sol";
import { OptimismReceiverDeploy } from "../deploy/OptimismReceiverDeploy.sol";

import { BaseDeployScript } from "./BaseDeployScript.sol";

import { Executor } from "src/Executor.sol";

/**
 * @notice Deploys an Executor and an OptimismReceiver on the chain selected via `CHAIN`.
 *
 * @dev Required env vars: `CHAIN` (forge alias) plus the corresponding `<ALIAS>_RPC_URL`.
 *      Optional: `CONFIG` overrides the default slug `optimism.<chain>`.
 *      Custom chains: also set `CHAIN_RPC_URL` and `CHAIN_ID`. See Makefile header.
 */
contract DeployOptimismFull is BaseDeployScript {

    string internal constant RECEIVER_TYPE = "optimism";

    function run() public {
        (string memory chainName,) = selectChain();

        string memory config = DeployConfig.loadConfig(
            string.concat(RECEIVER_TYPE, ".", chainName)
        );

        DeployExecutor.ExecutorParams memory executorParams = DeployExecutor.readExecutorParams(config);
        OptimismReceiverDeploy.Params memory receiverParams = OptimismReceiverDeploy.read(config);

        DeployExecutor.validateExecutorParams(executorParams, false);
        OptimismReceiverDeploy.validate(receiverParams);

        vm.startBroadcast();

        Executor executor = new Executor(executorParams.delay, executorParams.gracePeriod);
        address  receiver = address(new OptimismReceiver(receiverParams.sourceAuthority, address(executor)));

        DeployExecutor.setUpPermissions(executor, receiver, executorParams.guardian, msg.sender);

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
 * @dev `executor.address` in the JSON config must be the existing executor on the chosen
 *      chain. This script does NOT call setUpPermissions - granting the new receiver its
 *      SUBMISSION_ROLE on the existing executor is a governance action.
 */
contract DeployOptimismReceiverOnly is BaseDeployScript {

    string internal constant RECEIVER_TYPE = "optimism";

    function run() public {
        (string memory chainName,) = selectChain();

        string memory config = DeployConfig.loadConfig(
            string.concat(RECEIVER_TYPE, ".", chainName)
        );

        DeployExecutor.ExecutorParams memory executorParams = DeployExecutor.readExecutorParams(config);
        OptimismReceiverDeploy.Params memory receiverParams = OptimismReceiverDeploy.read(config);

        DeployExecutor.validateExecutorParams(executorParams, true);
        OptimismReceiverDeploy.validate(receiverParams);

        address executor = executorParams.existingAddress;

        vm.startBroadcast();

        address receiver = address(new OptimismReceiver(receiverParams.sourceAuthority, executor));

        vm.stopBroadcast();

        console.log("receiver deployed at:", receiver);
        console.log("re-using executor at:", executor);

        OptimismReceiverDeploy.verifyReceiverOnly({
            executor       : executor,
            receiver       : receiver,
            receiverParams : receiverParams
        });
    }

}
