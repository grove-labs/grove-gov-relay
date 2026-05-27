// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";
import { Script }  from "forge-std/Script.sol";

import { LZReceiver } from "lib/xchain-helpers/src/receivers/LZReceiver.sol";

import { DeployConfig }     from "../deploy/DeployConfig.sol";
import { DeployExecutor }   from "../deploy/DeployExecutor.sol";
import { LZReceiverDeploy } from "../deploy/LZReceiverDeploy.sol";

import { Executor } from "src/Executor.sol";

/**
 * @notice Deploys an Executor and an LZReceiver on the chain reachable through `RPC_URL`.
 *
 * @dev Required env vars:
 *      - RPC_URL: RPC endpoint of the destination chain
 *      - CONFIG : config slug, file `script/config/<CONFIG>.json` must exist
 */
contract DeployLZFull is Script {

    function run() public {
        DeployConfig.selectFork();

        string memory config = DeployConfig.loadConfig();

        DeployExecutor.ExecutorParams memory executorParams = DeployExecutor.readExecutorParams(config);
        LZReceiverDeploy.Params       memory receiverParams = LZReceiverDeploy.read(config);

        DeployExecutor.validateExecutorParams(executorParams, false);
        LZReceiverDeploy.validate(receiverParams);

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

        DeployExecutor.setUpPermissions(executor, receiver, msg.sender);

        vm.stopBroadcast();

        console.log("executor deployed at:", address(executor));
        console.log("receiver deployed at:", receiver);

        LZReceiverDeploy.verifyFull({
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
 * @notice Deploys an LZReceiver pointing at an already-deployed Executor.
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
contract DeployLZReceiverOnly is Script {

    function run() public {
        DeployConfig.selectFork();

        string memory config = DeployConfig.loadConfig();

        DeployExecutor.ExecutorParams memory executorParams = DeployExecutor.readExecutorParams(config);
        LZReceiverDeploy.Params       memory receiverParams = LZReceiverDeploy.read(config);

        DeployExecutor.validateExecutorParams(executorParams, true);
        LZReceiverDeploy.validate(receiverParams);

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

        LZReceiverDeploy.verifyReceiverOnly({
            executor       : executor,
            receiver       : receiver,
            receiverParams : receiverParams
        });
    }

}
