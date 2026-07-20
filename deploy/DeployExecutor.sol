// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { stdJson } from "forge-std/StdJson.sol";

import { VerificationHelpers } from "./VerificationHelpers.sol";

import { Executor } from "src/Executor.sol";

/**
 * @title  DeployExecutor
 * @notice All Executor-related deployment, configuration and verification logic.
 *
 * @dev This library is intentionally executor-only - per-receiver libraries should not need
 *      to edit this file when a new bridging solution is added.
 */
library DeployExecutor {

    using stdJson for string;

    struct ExecutorParams {
        address existingAddress;
        uint256 delay;
        uint256 gracePeriod;
        address guardian;
    }

    struct Deployment {
        address executor;
        address receiver;
        address deployer;
    }

    /**********************************************************************************************/
    /*** Config                                                                                 ***/
    /**********************************************************************************************/

    function readExecutorParams(string memory config)
        internal pure returns (ExecutorParams memory p)
    {
        p.existingAddress = config.readAddress(".executor.address");
        p.delay           = config.readUint(".executor.delay");
        p.gracePeriod     = config.readUint(".executor.gracePeriod");
        p.guardian        = config.readAddress(".executor.guardian");
    }

    /**********************************************************************************************/
    /*** Pre-deploy validation                                                                  ***/
    /**********************************************************************************************/

    function validateExecutorParams(ExecutorParams memory p, bool requireExisting) internal view {
        if (requireExisting) {
            VerificationHelpers.requireHasCode(p.existingAddress, "executor.address");

            Executor existing = Executor(p.existingAddress);
            require(
                existing.delay() == p.delay,
                "DeployExecutor/executor-delay-mismatch"
            );
            require(
                existing.gracePeriod() == p.gracePeriod,
                "DeployExecutor/executor-grace-period-mismatch"
            );
        } else {
            VerificationHelpers.requireZero(p.existingAddress, "executor.address");
            // Mirror Executor's constructor invariant (`Executor.MINIMUM_GRACE_PERIOD = 10 minutes`)
            // so a misconfigured grace period fails locally before any broadcasted tx is sent.
            // `delay` is intentionally unconstrained (the Executor accepts any uint256).
            require(
                p.gracePeriod >= 10 minutes,
                "DeployExecutor/executor-grace-period-below-minimum"
            );
        }
    }

    /**********************************************************************************************/
    /*** Post-deploy permission wiring                                                          ***/
    /**********************************************************************************************/

    /**
     * @notice Grants SUBMISSION_ROLE to the receiver, optionally grants GUARDIAN_ROLE to the
     *         configured guardian, and revokes the deployer's DEFAULT_ADMIN_ROLE.
     * @dev    Callable inside `vm.startBroadcast/stopBroadcast` so the calls are real on-chain
     *         transactions signed by the deployer. The guardian grant is skipped when `guardian`
     *         is the zero address, and must precede the admin revoke while the deployer still
     *         holds DEFAULT_ADMIN_ROLE.
     */
    function setUpPermissions(Executor executor, address receiver, address guardian, address deployer) internal {
        executor.grantRole(executor.SUBMISSION_ROLE(), receiver);

        if (guardian != address(0)) {
            executor.grantRole(executor.GUARDIAN_ROLE(), guardian);
        }

        executor.revokeRole(executor.DEFAULT_ADMIN_ROLE(), deployer);
    }

    /**********************************************************************************************/
    /*** Post-deploy verification                                                               ***/
    /**********************************************************************************************/

    function verifyDeployment(Deployment memory deployment, ExecutorParams memory params) internal view {
        Executor executor = Executor(deployment.executor);

        require(executor.delay()       == params.delay,       "DeployExecutor/incorrect-executor-delay");
        require(executor.gracePeriod() == params.gracePeriod, "DeployExecutor/incorrect-executor-grace-period");

        require(executor.actionsSetCount() == 0, "DeployExecutor/incorrect-executor-actions-set-count");

        require(executor.hasRole(executor.DEFAULT_ADMIN_ROLE(), deployment.executor) == true,  "DeployExecutor/executor-not-its-own-admin");

        require(executor.hasRole(executor.SUBMISSION_ROLE(),    deployment.deployer) == false, "DeployExecutor/deployer-has-executor-submission-role");
        require(executor.hasRole(executor.GUARDIAN_ROLE(),      deployment.deployer) == false, "DeployExecutor/deployer-has-executor-guardian-role");
        require(executor.hasRole(executor.DEFAULT_ADMIN_ROLE(), deployment.deployer) == false, "DeployExecutor/deployer-has-executor-admin-role");

        require(executor.hasRole(executor.SUBMISSION_ROLE(), deployment.receiver) == true, "DeployExecutor/receiver-does-not-have-executor-submission-role");

        if (params.guardian != address(0)) {
            require(executor.hasRole(executor.GUARDIAN_ROLE(), params.guardian) == true, "DeployExecutor/guardian-does-not-have-executor-guardian-role");
        }
    }

}
