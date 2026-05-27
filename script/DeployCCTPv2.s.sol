// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";

import { CCTPv2Receiver } from "lib/xchain-helpers/src/receivers/CCTPv2Receiver.sol";

import { CCTPv2ReceiverDeploy } from "../deploy/CCTPv2ReceiverDeploy.sol";
import { DeployConfig }         from "../deploy/DeployConfig.sol";
import { DeployExecutor }       from "../deploy/DeployExecutor.sol";

import { BaseDeployScript } from "./BaseDeployScript.sol";

import { Executor } from "src/Executor.sol";

/**
 * @notice Deploys an Executor and a CCTPv2Receiver on the chain selected via `CHAIN`.
 *
 * @dev Only CCTP v2 is supported. CCTP v1 is intentionally not used by these scripts.
 *      Required env vars: `CHAIN` (forge alias) plus the corresponding `<ALIAS>_RPC_URL`.
 *      Optional: `CONFIG` overrides the default slug `cctp-v2.<chain>`.
 *      Custom chains: also set `CHAIN_RPC_URL` and `CHAIN_ID`. See Makefile header.
 */
contract DeployCCTPv2Full is BaseDeployScript {

    string internal constant RECEIVER_TYPE = "cctp-v2";

    function run() public {
        (string memory chainName,) = selectChain();

        string memory config = DeployConfig.loadConfig(
            string.concat(RECEIVER_TYPE, ".", chainName)
        );

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
 * @dev `executor.address` in the JSON config must be the existing executor on the chosen
 *      chain. This script does NOT call setUpPermissions - granting the new receiver its
 *      SUBMISSION_ROLE on the existing executor is a governance action.
 */
contract DeployCCTPv2ReceiverOnly is BaseDeployScript {

    string internal constant RECEIVER_TYPE = "cctp-v2";

    function run() public {
        (string memory chainName,) = selectChain();

        string memory config = DeployConfig.loadConfig(
            string.concat(RECEIVER_TYPE, ".", chainName)
        );

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
        console.log("re-using executor at:", executor);

        CCTPv2ReceiverDeploy.verifyReceiverOnly({
            executor       : executor,
            receiver       : receiver,
            receiverParams : receiverParams
        });
    }

}
