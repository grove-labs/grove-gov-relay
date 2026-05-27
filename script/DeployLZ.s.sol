// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";

import { LZReceiver } from "lib/xchain-helpers/src/receivers/LZReceiver.sol";

import { DeployConfig }     from "../deploy/DeployConfig.sol";
import { DeployExecutor }   from "../deploy/DeployExecutor.sol";
import { LZReceiverDeploy } from "../deploy/LZReceiverDeploy.sol";

import { BaseDeployScript } from "./BaseDeployScript.sol";

import { Executor } from "src/Executor.sol";

/**
 * @notice Deploys an Executor and an LZReceiver on the chain selected via `CHAIN`.
 *
 * @dev Required env vars: `CHAIN` (forge alias) plus the corresponding `<ALIAS>_RPC_URL`.
 *      Optional: `CONFIG` overrides the default slug `lz.<chain>`.
 *      Custom chains: also set `CHAIN_RPC_URL` and `CHAIN_ID`. See Makefile header.
 */
contract DeployLZFull is BaseDeployScript {

    string internal constant RECEIVER_TYPE = "lz";

    function run() public {
        (string memory chainName,) = selectChain();

        string memory config = DeployConfig.loadConfig(
            string.concat(RECEIVER_TYPE, ".", chainName)
        );

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
 * @dev `executor.address` in the JSON config must be the existing executor on the chosen
 *      chain. This script does NOT call setUpPermissions - granting the new receiver its
 *      SUBMISSION_ROLE on the existing executor is a governance action.
 */
contract DeployLZReceiverOnly is BaseDeployScript {

    string internal constant RECEIVER_TYPE = "lz";

    function run() public {
        (string memory chainName,) = selectChain();

        string memory config = DeployConfig.loadConfig(
            string.concat(RECEIVER_TYPE, ".", chainName)
        );

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
        console.log("re-using executor at:", executor);

        LZReceiverDeploy.verifyReceiverOnly({
            executor       : executor,
            receiver       : receiver,
            receiverParams : receiverParams
        });
    }

}
