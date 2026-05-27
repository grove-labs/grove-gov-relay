// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";

import { AMBReceiver } from "lib/xchain-helpers/src/receivers/AMBReceiver.sol";

import { AMBReceiverDeploy } from "../deploy/AMBReceiverDeploy.sol";
import { DeployConfig }      from "../deploy/DeployConfig.sol";
import { DeployExecutor }    from "../deploy/DeployExecutor.sol";

import { BaseDeployScript } from "./BaseDeployScript.sol";

import { Executor } from "src/Executor.sol";

/**
 * @notice Deploys an Executor and an AMBReceiver on the chain selected via `CHAIN`.
 *
 * @dev Required env vars: `CHAIN` (forge alias) plus the corresponding `<ALIAS>_RPC_URL`.
 *      Optional: `CONFIG` overrides the default slug `amb.<chain>`.
 *      Custom chains: also set `CHAIN_RPC_URL` and `CHAIN_ID`. See Makefile header.
 */
contract DeployAMBFull is BaseDeployScript {

    string internal constant RECEIVER_TYPE = "amb";

    function run() public {
        (string memory chainName,) = selectChain();

        string memory config = DeployConfig.loadConfig(
            string.concat(RECEIVER_TYPE, ".", chainName)
        );

        DeployExecutor.ExecutorParams memory executorParams = DeployExecutor.readExecutorParams(config);
        AMBReceiverDeploy.Params      memory receiverParams = AMBReceiverDeploy.read(config);

        DeployExecutor.validateExecutorParams(executorParams, false);
        AMBReceiverDeploy.validate(receiverParams);

        vm.startBroadcast();

        Executor executor = new Executor(executorParams.delay, executorParams.gracePeriod);
        address  receiver = address(new AMBReceiver({
            _amb             : receiverParams.amb,
            _sourceChainId   : receiverParams.sourceChainId,
            _sourceAuthority : receiverParams.sourceAuthority,
            _target          : address(executor)
        }));

        DeployExecutor.setUpPermissions(executor, receiver, msg.sender);

        vm.stopBroadcast();

        console.log("executor deployed at:", address(executor));
        console.log("receiver deployed at:", receiver);

        AMBReceiverDeploy.verifyFull({
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
 * @notice Deploys an AMBReceiver pointing at an already-deployed Executor.
 *
 * @dev `executor.address` in the JSON config must be the existing executor on the chosen
 *      chain. This script does NOT call setUpPermissions - granting the new receiver its
 *      SUBMISSION_ROLE on the existing executor is a governance action.
 */
contract DeployAMBReceiverOnly is BaseDeployScript {

    string internal constant RECEIVER_TYPE = "amb";

    function run() public {
        (string memory chainName,) = selectChain();

        string memory config = DeployConfig.loadConfig(
            string.concat(RECEIVER_TYPE, ".", chainName)
        );

        DeployExecutor.ExecutorParams memory executorParams = DeployExecutor.readExecutorParams(config);
        AMBReceiverDeploy.Params      memory receiverParams = AMBReceiverDeploy.read(config);

        DeployExecutor.validateExecutorParams(executorParams, true);
        AMBReceiverDeploy.validate(receiverParams);

        address executor = executorParams.existingAddress;

        vm.startBroadcast();

        address receiver = address(new AMBReceiver({
            _amb             : receiverParams.amb,
            _sourceChainId   : receiverParams.sourceChainId,
            _sourceAuthority : receiverParams.sourceAuthority,
            _target          : executor
        }));

        vm.stopBroadcast();

        console.log("receiver deployed at:", receiver);
        console.log("re-using executor at:", executor);

        AMBReceiverDeploy.verifyReceiverOnly({
            executor       : executor,
            receiver       : receiver,
            receiverParams : receiverParams
        });
    }

}
