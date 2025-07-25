// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import { Domain }        from 'lib/xchain-helpers/src/testing/Domain.sol';
import { Bridge }        from 'lib/xchain-helpers/src/testing/Bridge.sol';
import { DomainHelpers } from 'lib/xchain-helpers/src/testing/Domain.sol';

import { IExecutor } from 'src/interfaces/IExecutor.sol';
import { Executor }  from 'src/Executor.sol';

import { IPayload } from './payloads/IPayload.sol';

import { PayloadWithEmit }        from './mocks/PayloadWithEmit.sol';
import { ReconfigurationPayload } from './mocks/ReconfigurationPayload.sol';

interface IL1Executor {
    function exec(address target, bytes calldata args)
        external
        payable
        returns (bytes memory out);
}

struct L2BridgeExecutorArguments {
    address ethereumGovernanceExecutor;
    uint256 delay;
    uint256 gracePeriod;
    address guardian;
}

abstract contract CrosschainTestBase is Test {

    using DomainHelpers for *;

    event TestEvent();

    address constant L1_GROVE_PROXY = 0x1369f7b2b38c76B6478c0f0E66D94923421891Ba;
    address constant L1_PAUSE_PROXY = 0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB;
    address GUARDIAN                = makeAddr('guardian');

    L2BridgeExecutorArguments defaultL2BridgeExecutorArgs = L2BridgeExecutorArguments({
        ethereumGovernanceExecutor: L1_GROVE_PROXY,
        delay:                      600,
        gracePeriod:                1200,
        guardian:                   GUARDIAN
    });

    Domain mainnet;
    Domain remote;
    Bridge bridge;

    Executor bridgeExecutor;
    address  bridgeReceiver;

    function setUp() public {
        mainnet = getChain("mainnet").createFork();

        setupDomain();

        remote.selectFork();

        bridgeExecutor = new Executor(
            defaultL2BridgeExecutorArgs.delay,
            defaultL2BridgeExecutorArgs.gracePeriod
        );
        bridgeExecutor.grantRole(bridgeExecutor.SUBMISSION_ROLE(),     bridgeReceiver);
        bridgeExecutor.grantRole(bridgeExecutor.GUARDIAN_ROLE(),       defaultL2BridgeExecutorArgs.guardian);
        bridgeExecutor.revokeRole(bridgeExecutor.DEFAULT_ADMIN_ROLE(), address(this));
    }

    function deployCrosschainPayload(IPayload targetPayload, address bridgeReceiver) internal virtual returns (IPayload);
    function relayMessagesAcrossBridge() internal virtual;
    function setupDomain() internal virtual;

    function preparePayloadExecution() internal {
        remote.selectFork();

        IPayload targetPayload = IPayload(new PayloadWithEmit());

        mainnet.selectFork();

        IPayload crosschainPayload = deployCrosschainPayload(
            targetPayload,
            bridgeReceiver
        );

        vm.prank(L1_PAUSE_PROXY);
        IL1Executor(L1_GROVE_PROXY).exec(
            address(crosschainPayload),
            abi.encodeWithSelector(IPayload.execute.selector)
        );

        relayMessagesAcrossBridge();
    }

    function testFuzz_basicCrosschainPayloadExecution(uint256 delay) public {
        delay = bound(
            delay,
            defaultL2BridgeExecutorArgs.delay,
            defaultL2BridgeExecutorArgs.delay + defaultL2BridgeExecutorArgs.gracePeriod
        );

        preparePayloadExecution();

        skip(delay);

        vm.expectEmit(address(bridgeExecutor));
        emit TestEvent();
        bridgeExecutor.execute(0);
    }

    function testFuzz_actionExecutionFailsAfterGracePeriod(uint delay) public {
        delay = bound(
            delay,
            defaultL2BridgeExecutorArgs.delay + defaultL2BridgeExecutorArgs.gracePeriod + 1,
            10_000_000
        );

        preparePayloadExecution();

        skip(delay);

        vm.expectRevert(IExecutor.OnlyQueuedActions.selector);
        bridgeExecutor.execute(0);
    }

    function testFuzz_actionExecutionFailsBeforeTimelock(uint delay) public {
        delay = bound(delay, 0, defaultL2BridgeExecutorArgs.delay - 1);

        preparePayloadExecution();

        skip(delay);

        vm.expectRevert(IExecutor.TimelockNotFinished.selector);
        bridgeExecutor.execute(0);
    }

    function test_nonExistentActionExecutionFails() public {
        vm.expectRevert();
        bridgeExecutor.execute(0);

        preparePayloadExecution();

        skip(defaultL2BridgeExecutorArgs.delay);

        vm.expectRevert();
        bridgeExecutor.execute(1);

        vm.expectEmit(address(bridgeExecutor));
        emit TestEvent();
        bridgeExecutor.execute(0);
    }

    function test_onlyGuardianCanCancel() public {
        address notGuardian = makeAddr('notGuardian');

        preparePayloadExecution();

        assertEq(
            bridgeExecutor.getActionsSetById(0).canceled,
            false
        );

        vm.expectRevert();
        vm.prank(notGuardian);
        bridgeExecutor.cancel(0);

        assertEq(
            bridgeExecutor.getActionsSetById(0).canceled,
            false
        );

        vm.prank(defaultL2BridgeExecutorArgs.guardian);
        bridgeExecutor.cancel(0);

        assertEq(
            bridgeExecutor.getActionsSetById(0).canceled,
            true
        );
    }

    function test_canceledActionCannotBeCanceled() public {
        preparePayloadExecution();

        vm.prank(defaultL2BridgeExecutorArgs.guardian);
        bridgeExecutor.cancel(0);

        vm.expectRevert(IExecutor.OnlyQueuedActions.selector);
        vm.prank(defaultL2BridgeExecutorArgs.guardian);
        bridgeExecutor.cancel(0);
    }

    function test_executedActionCannotBeCanceled() public {
        preparePayloadExecution();

        skip(defaultL2BridgeExecutorArgs.delay);

        bridgeExecutor.execute(0);

        vm.expectRevert(IExecutor.OnlyQueuedActions.selector);
        vm.prank(defaultL2BridgeExecutorArgs.guardian);
        bridgeExecutor.cancel(0);
    }

    function test_expiredActionCannotBeCanceled() public {
        preparePayloadExecution();

        skip(defaultL2BridgeExecutorArgs.delay + defaultL2BridgeExecutorArgs.gracePeriod + 1);

        vm.expectRevert(IExecutor.OnlyQueuedActions.selector);
        vm.prank(defaultL2BridgeExecutorArgs.guardian);
        bridgeExecutor.cancel(0);
    }

    function test_canceledActionCannotBeExecuted() public {
        preparePayloadExecution();

        skip(defaultL2BridgeExecutorArgs.delay);

        vm.prank(defaultL2BridgeExecutorArgs.guardian);
        bridgeExecutor.cancel(0);

        vm.expectRevert(IExecutor.OnlyQueuedActions.selector);
        bridgeExecutor.execute(0);
    }

    function test_executingMultipleActions() public {
        preparePayloadExecution();
        skip(1);
        preparePayloadExecution();
        skip(1);
        preparePayloadExecution();

        skip(defaultL2BridgeExecutorArgs.delay);

        assertEq(
            bridgeExecutor.getActionsSetById(0).executed,
            false
        );
        assertEq(
            bridgeExecutor.getActionsSetById(1).executed,
            false
        );
        assertEq(
            bridgeExecutor.getActionsSetById(2).executed,
            false
        );

        bridgeExecutor.execute(1);

        assertEq(
            bridgeExecutor.getActionsSetById(0).executed,
            false
        );
        assertEq(
            bridgeExecutor.getActionsSetById(1).executed,
            true
        );
        assertEq(
            bridgeExecutor.getActionsSetById(2).executed,
            false
        );

        bridgeExecutor.execute(2);

        assertEq(
            bridgeExecutor.getActionsSetById(0).executed,
            false
        );
        assertEq(
            bridgeExecutor.getActionsSetById(1).executed,
            true
        );
        assertEq(
            bridgeExecutor.getActionsSetById(2).executed,
            true
        );

        bridgeExecutor.execute(0);

        assertEq(
            bridgeExecutor.getActionsSetById(0).executed,
            true
        );
        assertEq(
            bridgeExecutor.getActionsSetById(1).executed,
            true
        );
        assertEq(
            bridgeExecutor.getActionsSetById(2).executed,
            true
        );
    }

    function test_selfReconfiguration() public {
        remote.selectFork();

        L2BridgeExecutorArguments memory newL2BridgeExecutorParams = L2BridgeExecutorArguments({
            ethereumGovernanceExecutor: defaultL2BridgeExecutorArgs.ethereumGovernanceExecutor,
            delay:                      1200,
            gracePeriod:                1800,
            guardian:                   makeAddr('newGuardian')
        });

        assertEq(
            bridgeExecutor.delay(),
            defaultL2BridgeExecutorArgs.delay
        );
        assertEq(
            bridgeExecutor.gracePeriod(),
            defaultL2BridgeExecutorArgs.gracePeriod
        );
        assertEq(
            bridgeExecutor.hasRole(bridgeExecutor.GUARDIAN_ROLE(), defaultL2BridgeExecutorArgs.guardian),
            true
        );
        assertEq(
            bridgeExecutor.hasRole(bridgeExecutor.GUARDIAN_ROLE(), newL2BridgeExecutorParams.guardian),
            false
        );

        IPayload reconfigurationPayload = IPayload(new ReconfigurationPayload(
            newL2BridgeExecutorParams.delay,
            newL2BridgeExecutorParams.gracePeriod,
            defaultL2BridgeExecutorArgs.guardian,
            newL2BridgeExecutorParams.guardian
        ));

        mainnet.selectFork();

        IPayload crosschainPayload = deployCrosschainPayload(
            reconfigurationPayload,
            bridgeReceiver
        );

        vm.prank(L1_PAUSE_PROXY);
        IL1Executor(L1_GROVE_PROXY).exec(
            address(crosschainPayload),
            abi.encodeWithSelector(IPayload.execute.selector)
        );

        relayMessagesAcrossBridge();

        skip(defaultL2BridgeExecutorArgs.delay);

        bridgeExecutor.execute(0);

        assertEq(
            bridgeExecutor.delay(),
            newL2BridgeExecutorParams.delay
        );
        assertEq(
            bridgeExecutor.gracePeriod(),
            newL2BridgeExecutorParams.gracePeriod
        );
        assertEq(
            bridgeExecutor.hasRole(bridgeExecutor.GUARDIAN_ROLE(), defaultL2BridgeExecutorArgs.guardian),
            false
        );
        assertEq(
            bridgeExecutor.hasRole(bridgeExecutor.GUARDIAN_ROLE(), newL2BridgeExecutorParams.guardian),
            true
        );
    }

}
