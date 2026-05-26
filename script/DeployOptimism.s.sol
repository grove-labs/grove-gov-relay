// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";
import { Script }  from "forge-std/Script.sol";

import { OptimismReceiver } from "lib/xchain-helpers/src/receivers/OptimismReceiver.sol";

import { DeployConfig }        from "../deploy/DeployConfig.sol";
import { Verify }              from "../deploy/Verify.sol";
import { VerificationHelpers } from "../deploy/VerificationHelpers.sol";

import { Executor } from "src/Executor.sol";

/**
 * @notice Deploys an Executor and an OptimismReceiver on the chain reachable through `RPC_URL`.
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
 *          "sourceAuthority": "0x..."
 *        }
 *      }
 */
contract DeployOptimismFull is Script {

    function run() public {
        DeployConfig.selectFork();

        string memory config = DeployConfig.loadConfig();

        DeployConfig.ExecutorParams memory executorParams   = DeployConfig.readExecutorParams(config);
        address                            sourceAuthority = DeployConfig.readSourceAuthority(config);

        VerificationHelpers.validateExecutorParams(executorParams, false);
        VerificationHelpers.validateSourceAuthority(sourceAuthority);

        vm.startBroadcast();

        Executor executor = new Executor(executorParams.delay, executorParams.gracePeriod);
        address  receiver = address(new OptimismReceiver(sourceAuthority, address(executor)));

        executor.grantRole(executor.SUBMISSION_ROLE(),     receiver);
        executor.revokeRole(executor.DEFAULT_ADMIN_ROLE(), msg.sender);

        vm.stopBroadcast();

        console.log("executor deployed at:", address(executor));
        console.log("receiver deployed at:", receiver);

        Verify.verifyOptimismDeployment({
            deployment : Verify.Deployment({
                executor : address(executor),
                receiver : receiver,
                deployer : msg.sender
            }),
            params : Verify.ExecutorParams({
                delay       : executorParams.delay,
                gracePeriod : executorParams.gracePeriod
            }),
            expectedSourceAuthority : sourceAuthority
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
 *      Note: this script does NOT call setUpExecutorPermissions - granting the new receiver
 *      its SUBMISSION_ROLE on the existing executor must be done via a governance payload,
 *      since the deployer no longer holds DEFAULT_ADMIN_ROLE on the executor after the
 *      original deployment.
 */
contract DeployOptimismReceiverOnly is Script {

    function run() public {
        DeployConfig.selectFork();

        string memory config = DeployConfig.loadConfig();

        DeployConfig.ExecutorParams memory executorParams   = DeployConfig.readExecutorParams(config);
        address                            sourceAuthority = DeployConfig.readSourceAuthority(config);

        VerificationHelpers.validateExecutorParams(executorParams, true);
        VerificationHelpers.validateSourceAuthority(sourceAuthority);

        address executor = executorParams.existingAddress;

        vm.startBroadcast();

        address receiver = address(new OptimismReceiver(sourceAuthority, executor));

        vm.stopBroadcast();

        console.log("receiver deployed at:", receiver);
        console.log("re-using executor at :", executor);

        Verify.verifyOptimismReceiverDeployment({
            executor                : executor,
            receiver                : receiver,
            expectedSourceAuthority : sourceAuthority
        });
    }

}
