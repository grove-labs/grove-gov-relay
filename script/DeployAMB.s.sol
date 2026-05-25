// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";
import { Script }  from "forge-std/Script.sol";

import { Deploy }        from "../deploy/Deploy.sol";
import { DeployConfig }  from "../deploy/DeployConfig.sol";
import { Verify }        from "../deploy/Verify.sol";

/**
 * @notice Deploys an Executor and an AMBReceiver on the chain reachable through `RPC_URL`.
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
 *          "amb":             "0x...",       // local AMB contract address
 *          "sourceChainId":   <uint>,        // source chain id, e.g. 1 for Ethereum
 *          "sourceAuthority": "0x..."        // source authority address
 *        }
 *      }
 */
contract DeployAMBFull is Script {

    function run() public {
        DeployConfig.selectFork();

        string memory config = DeployConfig.loadConfig();

        DeployConfig.ExecutorParams    memory executorParams = DeployConfig.readExecutorParams(config);
        DeployConfig.AMBReceiverParams memory receiverParams = DeployConfig.readAMBReceiverParams(config);

        DeployConfig.validateExecutorParams(executorParams, false);
        DeployConfig.validateAMBReceiverParams(receiverParams);

        vm.startBroadcast();

        address executor = Deploy.deployExecutor(executorParams.delay, executorParams.gracePeriod);
        address receiver = Deploy.deployAMBReceiver({
            amb             : receiverParams.amb,
            sourceChainId   : receiverParams.sourceChainId,
            sourceAuthority : receiverParams.sourceAuthority,
            executor        : executor
        });

        Deploy.setUpExecutorPermissions(executor, receiver, msg.sender);

        vm.stopBroadcast();

        console.log("executor deployed at:", executor);
        console.log("receiver deployed at:", receiver);

        Verify.verifyAMBDeployment({
            deployment : Verify.Deployment({
                executor : executor,
                receiver : receiver,
                deployer : msg.sender
            }),
            params : Verify.ExecutorParams({
                delay       : executorParams.delay,
                gracePeriod : executorParams.gracePeriod
            }),
            amb                     : receiverParams.amb,
            expectedSourceChainId   : receiverParams.sourceChainId,
            expectedSourceAuthority : receiverParams.sourceAuthority
        });
    }

}

/**
 * @notice Deploys an AMBReceiver pointing at an already-deployed Executor.
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
contract DeployAMBReceiverOnly is Script {

    function run() public {
        DeployConfig.selectFork();

        string memory config = DeployConfig.loadConfig();

        DeployConfig.ExecutorParams    memory executorParams = DeployConfig.readExecutorParams(config);
        DeployConfig.AMBReceiverParams memory receiverParams = DeployConfig.readAMBReceiverParams(config);

        DeployConfig.validateExecutorParams(executorParams, true);
        DeployConfig.validateAMBReceiverParams(receiverParams);

        address executor = executorParams.existingAddress;

        vm.startBroadcast();

        address receiver = Deploy.deployAMBReceiver({
            amb             : receiverParams.amb,
            sourceChainId   : receiverParams.sourceChainId,
            sourceAuthority : receiverParams.sourceAuthority,
            executor        : executor
        });

        vm.stopBroadcast();

        console.log("receiver deployed at:", receiver);
        console.log("re-using executor at :", executor);

        Verify.verifyAMBReceiverDeployment({
            receiver                : receiver,
            executor                : executor,
            amb                     : receiverParams.amb,
            expectedSourceChainId   : receiverParams.sourceChainId,
            expectedSourceAuthority : receiverParams.sourceAuthority
        });
    }

}
