// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import { Executor } from "../src/Executor.sol";

import { DeployExecutor } from "../deploy/DeployExecutor.sol";

// Wrapper that re-exposes library functions externally so vm.expectRevert can observe reverts,
// and so that the harness itself owns the freshly-deployed Executor (i.e. holds DEFAULT_ADMIN_ROLE).
contract DeployExecutorHarness {

    function validateExecutorParams(DeployExecutor.ExecutorParams memory ep, bool requireExisting) external view {
        DeployExecutor.validateExecutorParams(ep, requireExisting);
    }

    function deployExecutor(uint256 delay, uint256 gracePeriod) external returns (Executor) {
        return new Executor(delay, gracePeriod);
    }

    function setUpPermissions(Executor executor, address receiver, address deployer) external {
        DeployExecutor.setUpPermissions(executor, receiver, deployer);
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
    }

    function test_readExecutorParams_ambExample() public view {
        string memory config = _readExample("amb");

        DeployExecutor.ExecutorParams memory ep = DeployExecutor.readExecutorParams(config);
        assertEq(ep.existingAddress, address(0));
        assertEq(ep.delay,           0);
        assertEq(ep.gracePeriod,     7 days);
    }

    /**********************************************************************************************/
    /*** validateExecutorParams - full deployment branch (requireExisting = false)              ***/
    /**********************************************************************************************/

    function test_validateExecutorParams_full_zeroAddress() public view {
        DeployExecutor.ExecutorParams memory ep = DeployExecutor.ExecutorParams({
            existingAddress : address(0),
            delay           : 0,
            gracePeriod     : 10 minutes
        });
        harness.validateExecutorParams(ep, false);
    }

    function test_validateExecutorParams_full_revertsOnNonZero() public {
        DeployExecutor.ExecutorParams memory ep = DeployExecutor.ExecutorParams({
            existingAddress : makeAddr("executor"),
            delay           : 0,
            gracePeriod     : 7 days
        });
        vm.expectRevert("VerificationHelpers/expected-unset-address: executor.address");
        harness.validateExecutorParams(ep, false);
    }

    function test_validateExecutorParams_full_revertsOnGracePeriodBelowMinimum() public {
        DeployExecutor.ExecutorParams memory ep = DeployExecutor.ExecutorParams({
            existingAddress : address(0),
            delay           : 0,
            gracePeriod     : 10 minutes - 1
        });
        vm.expectRevert("DeployExecutor/executor-grace-period-below-minimum");
        harness.validateExecutorParams(ep, false);
    }

    function test_validateExecutorParams_full_passesOnGracePeriodAtMinimum() public view {
        DeployExecutor.ExecutorParams memory ep = DeployExecutor.ExecutorParams({
            existingAddress : address(0),
            delay           : 0,
            gracePeriod     : 10 minutes
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
            gracePeriod     : 1
        });
        vm.expectRevert("VerificationHelpers/zero-address: executor.address");
        harness.validateExecutorParams(ep, true);
    }

    function test_validateExecutorParams_receiverOnly_revertsOnNoCode() public {
        DeployExecutor.ExecutorParams memory ep = DeployExecutor.ExecutorParams({
            existingAddress : makeAddr("executor"),
            delay           : 0,
            gracePeriod     : 1
        });
        vm.expectRevert("VerificationHelpers/no-code-at-address: executor.address");
        harness.validateExecutorParams(ep, true);
    }

    function test_validateExecutorParams_receiverOnly_passesOnMatchingLiveExecutor() public {
        Executor existing = new Executor(1 hours, 7 days);
        DeployExecutor.ExecutorParams memory ep = DeployExecutor.ExecutorParams({
            existingAddress : address(existing),
            delay           : 1 hours,
            gracePeriod     : 7 days
        });
        harness.validateExecutorParams(ep, true);
    }

    function test_validateExecutorParams_receiverOnly_revertsOnDelayMismatch() public {
        Executor existing = new Executor(1 hours, 7 days);
        DeployExecutor.ExecutorParams memory ep = DeployExecutor.ExecutorParams({
            existingAddress : address(existing),
            delay           : 2 hours,
            gracePeriod     : 7 days
        });
        vm.expectRevert("DeployExecutor/executor-delay-mismatch");
        harness.validateExecutorParams(ep, true);
    }

    function test_validateExecutorParams_receiverOnly_revertsOnGracePeriodMismatch() public {
        Executor existing = new Executor(1 hours, 7 days);
        DeployExecutor.ExecutorParams memory ep = DeployExecutor.ExecutorParams({
            existingAddress : address(existing),
            delay           : 1 hours,
            gracePeriod     : 14 days
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

        harness.setUpPermissions(executor, receiver, address(harness));

        // Post-conditions: deployer admin revoked, receiver gained submission, executor self-admin
        // is preserved (granted by the constructor, never touched here).
        assertFalse(executor.hasRole(ADMIN,      address(harness)));
        assertTrue (executor.hasRole(SUBMISSION, receiver));
        assertTrue (executor.hasRole(ADMIN,      address(executor)));
    }

    function test_setUpPermissions_revokedDeployerCannotGrantFurther() public {
        Executor executor = harness.deployExecutor(1 hours, 7 days);
        address  receiver = makeAddr("receiver");

        harness.setUpPermissions(executor, receiver, address(harness));

        // Deployer no longer has admin -> any subsequent role grant from the harness must revert.
        bytes32 SUBMISSION = executor.SUBMISSION_ROLE();
        vm.prank(address(harness));
        vm.expectRevert();
        executor.grantRole(SUBMISSION, makeAddr("intruder"));
    }

}
