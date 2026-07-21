// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import { Executor } from "../src/Executor.sol";

import { DeployExecutor } from "../deploy/DeployExecutor.sol";

// Wrapper that re-exposes library functions externally so vm.expectRevert can observe reverts,
// and so that the harness itself owns the freshly-deployed Executor (i.e. holds DEFAULT_ADMIN_ROLE).
contract DeployExecutorHarness {

    function readExecutorParams(string memory config) external pure returns (DeployExecutor.ExecutorParams memory) {
        return DeployExecutor.readExecutorParams(config);
    }

    function validateExecutorParams(DeployExecutor.ExecutorParams memory ep, bool requireExisting) external view {
        DeployExecutor.validateExecutorParams(ep, requireExisting);
    }

    function deployExecutor(uint256 delay, uint256 gracePeriod) external returns (Executor) {
        return new Executor(delay, gracePeriod);
    }

    function setUpPermissions(Executor executor, address receiver, address guardian, address deployer) external {
        DeployExecutor.setUpPermissions(executor, receiver, guardian, deployer);
    }

}

contract DeployExecutorTests is Test {

    DeployExecutorHarness harness;

    function setUp() public {
        harness = new DeployExecutorHarness();
    }

    function _readExample(string memory slug) internal view returns (string memory config) {
        string memory path = string.concat(
            vm.projectRoot(),
            "/script/config/",
            slug,
            ".example.json"
        );
        config = vm.readFile(path);
    }

    /**********************************************************************************************/
    /*** readExecutorParams                                                                     ***/
    /**********************************************************************************************/

    function test_readExecutorParams_arbitrumExample() public view {
        string memory config = _readExample("arbitrum");

        DeployExecutor.ExecutorParams memory ep = DeployExecutor.readExecutorParams(config);
        assertEq(ep.existingAddress, address(0));
        assertEq(ep.delay,           0);
        assertEq(ep.gracePeriod,     7 days);
        assertEq(ep.guardian,        address(0));
    }

    function test_readExecutorParams_ambExample() public view {
        string memory config = _readExample("amb");

        DeployExecutor.ExecutorParams memory ep = DeployExecutor.readExecutorParams(config);
        assertEq(ep.existingAddress, address(0));
        assertEq(ep.delay,           0);
        assertEq(ep.gracePeriod,     7 days);
        assertEq(ep.guardian,        address(0));
    }

    function test_readExecutorParams_readsGuardianWhenPresent() public {
        address guardian = makeAddr("guardian");
        string memory config = string.concat(
            '{"executor":{"address":"0x0000000000000000000000000000000000000000","delay":0,"gracePeriod":604800,"guardian":"',
            vm.toString(guardian),
            '"}}'
        );

        DeployExecutor.ExecutorParams memory ep = DeployExecutor.readExecutorParams(config);
        assertEq(ep.guardian, guardian);
    }

    function test_readExecutorParams_revertsWhenGuardianAbsent() public {
        string memory config =
            '{"executor":{"address":"0x0000000000000000000000000000000000000000","delay":0,"gracePeriod":604800}}';

        vm.expectRevert();
        harness.readExecutorParams(config);
    }

    /**********************************************************************************************/
    /*** validateExecutorParams - full deployment branch (requireExisting = false)              ***/
    /**********************************************************************************************/

    function test_validateExecutorParams_full_zeroAddress() public view {
        DeployExecutor.ExecutorParams memory ep = DeployExecutor.ExecutorParams({
            existingAddress : address(0),
            delay           : 0,
            gracePeriod     : 10 minutes,
            guardian        : address(0)
        });
        harness.validateExecutorParams(ep, false);
    }

    function test_validateExecutorParams_full_revertsOnNonZero() public {
        DeployExecutor.ExecutorParams memory ep = DeployExecutor.ExecutorParams({
            existingAddress : makeAddr("executor"),
            delay           : 0,
            gracePeriod     : 7 days,
            guardian        : address(0)
        });
        vm.expectRevert("VerificationHelpers/expected-unset-address: executor.address");
        harness.validateExecutorParams(ep, false);
    }

    function test_validateExecutorParams_full_revertsOnGracePeriodBelowMinimum() public {
        DeployExecutor.ExecutorParams memory ep = DeployExecutor.ExecutorParams({
            existingAddress : address(0),
            delay           : 0,
            gracePeriod     : 10 minutes - 1,
            guardian        : address(0)
        });
        vm.expectRevert("DeployExecutor/executor-grace-period-below-minimum");
        harness.validateExecutorParams(ep, false);
    }

    function test_validateExecutorParams_full_passesOnGracePeriodAtMinimum() public view {
        DeployExecutor.ExecutorParams memory ep = DeployExecutor.ExecutorParams({
            existingAddress : address(0),
            delay           : 0,
            gracePeriod     : 10 minutes,
            guardian        : address(0)
        });
        harness.validateExecutorParams(ep, false);
    }

    /**********************************************************************************************/
    /*** validateExecutorParams - receiver-only branch (requireExisting = true)                 ***/
    /**********************************************************************************************/

    function test_validateExecutorParams_receiverOnly_revertsOnZero() public {
        DeployExecutor.ExecutorParams memory ep = DeployExecutor.ExecutorParams({
            existingAddress : address(0),
            delay           : 0,
            gracePeriod     : 1,
            guardian        : address(0)
        });
        vm.expectRevert("VerificationHelpers/zero-address: executor.address");
        harness.validateExecutorParams(ep, true);
    }

    function test_validateExecutorParams_receiverOnly_revertsOnNoCode() public {
        DeployExecutor.ExecutorParams memory ep = DeployExecutor.ExecutorParams({
            existingAddress : makeAddr("executor"),
            delay           : 0,
            gracePeriod     : 1,
            guardian        : address(0)
        });
        vm.expectRevert("VerificationHelpers/no-code-at-address: executor.address");
        harness.validateExecutorParams(ep, true);
    }

    function test_validateExecutorParams_receiverOnly_passesOnMatchingLiveExecutor() public {
        Executor existing = new Executor(1 hours, 7 days);
        DeployExecutor.ExecutorParams memory ep = DeployExecutor.ExecutorParams({
            existingAddress : address(existing),
            delay           : 1 hours,
            gracePeriod     : 7 days,
            guardian        : address(0)
        });
        harness.validateExecutorParams(ep, true);
    }

    function test_validateExecutorParams_receiverOnly_revertsOnDelayMismatch() public {
        Executor existing = new Executor(1 hours, 7 days);
        DeployExecutor.ExecutorParams memory ep = DeployExecutor.ExecutorParams({
            existingAddress : address(existing),
            delay           : 2 hours,
            gracePeriod     : 7 days,
            guardian        : address(0)
        });
        vm.expectRevert("DeployExecutor/executor-delay-mismatch");
        harness.validateExecutorParams(ep, true);
    }

    function test_validateExecutorParams_receiverOnly_revertsOnGracePeriodMismatch() public {
        Executor existing = new Executor(1 hours, 7 days);
        DeployExecutor.ExecutorParams memory ep = DeployExecutor.ExecutorParams({
            existingAddress : address(existing),
            delay           : 1 hours,
            gracePeriod     : 14 days,
            guardian        : address(0)
        });
        vm.expectRevert("DeployExecutor/executor-grace-period-mismatch");
        harness.validateExecutorParams(ep, true);
    }

    /**********************************************************************************************/
    /*** setUpPermissions: post-deploy role wiring                                              ***/
    /**********************************************************************************************/

    function test_setUpPermissions_grantsSubmissionAndRevokesDeployerAdmin() public {
        Executor executor = harness.deployExecutor(1 hours, 7 days);
        address  receiver = makeAddr("receiver");

        bytes32 ADMIN      = executor.DEFAULT_ADMIN_ROLE();
        bytes32 SUBMISSION = executor.SUBMISSION_ROLE();

        // Pre-conditions: harness (the deployer) holds admin; receiver has no roles.
        assertTrue (executor.hasRole(ADMIN,      address(harness)));
        assertFalse(executor.hasRole(SUBMISSION, address(harness)));
        assertFalse(executor.hasRole(SUBMISSION, receiver));

        harness.setUpPermissions(executor, receiver, address(0), address(harness));

        // Post-conditions: deployer admin revoked, receiver gained submission, executor self-admin
        // is preserved (granted by the constructor, never touched here).
        assertFalse(executor.hasRole(ADMIN,      address(harness)));
        assertTrue (executor.hasRole(SUBMISSION, receiver));
        assertTrue (executor.hasRole(ADMIN,      address(executor)));
    }

    function test_setUpPermissions_revokedDeployerCannotGrantFurther() public {
        Executor executor = harness.deployExecutor(1 hours, 7 days);
        address  receiver = makeAddr("receiver");

        harness.setUpPermissions(executor, receiver, address(0), address(harness));

        // Deployer no longer has admin -> any subsequent role grant from the harness must revert.
        bytes32 SUBMISSION = executor.SUBMISSION_ROLE();
        vm.prank(address(harness));
        vm.expectRevert();
        executor.grantRole(SUBMISSION, makeAddr("intruder"));
    }

    function test_setUpPermissions_grantsGuardianWhenSet() public {
        Executor executor = harness.deployExecutor(1 hours, 7 days);
        address  receiver = makeAddr("receiver");
        address  guardian = makeAddr("guardian");

        bytes32 ADMIN      = executor.DEFAULT_ADMIN_ROLE();
        bytes32 SUBMISSION = executor.SUBMISSION_ROLE();
        bytes32 GUARDIAN   = executor.GUARDIAN_ROLE();

        assertFalse(executor.hasRole(GUARDIAN, guardian));

        harness.setUpPermissions(executor, receiver, guardian, address(harness));

        assertTrue (executor.hasRole(GUARDIAN,   guardian));
        assertTrue (executor.hasRole(SUBMISSION, receiver));
        assertFalse(executor.hasRole(ADMIN,      address(harness)));
    }

    function test_setUpPermissions_skipsGuardianWhenZero() public {
        Executor executor = harness.deployExecutor(1 hours, 7 days);
        address  receiver = makeAddr("receiver");

        bytes32 ADMIN      = executor.DEFAULT_ADMIN_ROLE();
        bytes32 SUBMISSION = executor.SUBMISSION_ROLE();
        bytes32 GUARDIAN   = executor.GUARDIAN_ROLE();

        harness.setUpPermissions(executor, receiver, address(0), address(harness));

        // No guardian granted; the rest of the wiring is unaffected.
        assertFalse(executor.hasRole(GUARDIAN,   address(0)));
        assertTrue (executor.hasRole(SUBMISSION, receiver));
        assertFalse(executor.hasRole(ADMIN,      address(harness)));
    }

    /**********************************************************************************************/
    /*** verifyDeployment: guardian assertion                                                   ***/
    /**********************************************************************************************/

    function test_verifyDeployment_passesWithConfiguredGuardian() public {
        Executor executor = harness.deployExecutor(1 hours, 7 days);
        address  receiver = makeAddr("receiver");
        address  guardian = makeAddr("guardian");

        harness.setUpPermissions(executor, receiver, guardian, address(harness));

        DeployExecutor.verifyDeployment(
            DeployExecutor.Deployment({
                executor : address(executor),
                receiver : receiver,
                deployer : address(harness)
            }),
            DeployExecutor.ExecutorParams({
                existingAddress : address(0),
                delay           : 1 hours,
                gracePeriod     : 7 days,
                guardian        : guardian
            })
        );
    }

    function test_verifyDeployment_revertsWhenConfiguredGuardianMissingRole() public {
        Executor executor = harness.deployExecutor(1 hours, 7 days);
        address  receiver = makeAddr("receiver");
        address  guardian = makeAddr("guardian");

        // Wire everything EXCEPT the guardian grant, then assert verify catches the omission.
        harness.setUpPermissions(executor, receiver, address(0), address(harness));

        vm.expectRevert("DeployExecutor/guardian-does-not-have-executor-guardian-role");
        this.verifyDeploymentExternal(
            DeployExecutor.Deployment({
                executor : address(executor),
                receiver : receiver,
                deployer : address(harness)
            }),
            DeployExecutor.ExecutorParams({
                existingAddress : address(0),
                delay           : 1 hours,
                gracePeriod     : 7 days,
                guardian        : guardian
            })
        );
    }

    function verifyDeploymentExternal(
        DeployExecutor.Deployment     memory deployment,
        DeployExecutor.ExecutorParams memory params
    ) external view {
        DeployExecutor.verifyDeployment(deployment, params);
    }

}
