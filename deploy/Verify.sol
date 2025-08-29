// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { ArbitrumReceiver } from "lib/xchain-helpers/src/receivers/ArbitrumReceiver.sol";
import { CCTPReceiver }     from "lib/xchain-helpers/src/receivers/CCTPReceiver.sol";
import { OptimismReceiver } from "lib/xchain-helpers/src/receivers/OptimismReceiver.sol";

import { Executor } from "src/Executor.sol";

library Verify {

    struct Deployment {
        address executor;
        address receiver;
        address deployer;
    }

    struct ExecutorParams {
        uint256 delay;
        uint256 gracePeriod;
    }

    function verifyArbitrumDeployment(
        Deployment     memory deployment,
        ExecutorParams memory params
    ) internal view {
        verifyExecutorDeployment(deployment, params);
        verifyArbitrumReceiverDeployment(deployment.executor, deployment.receiver);
    }

    function verifyOptimismDeployment(
        Deployment     memory deployment,
        ExecutorParams memory params
    ) internal view {
        verifyExecutorDeployment(deployment, params);
        verifyOptimismReceiverDeployment(deployment.executor, deployment.receiver);
    }

    function verifyCctpDeployment(
        Deployment     memory deployment,
        ExecutorParams memory params,
        address               cctpMessageTransmitter
    ) internal view {
        verifyExecutorDeployment(deployment, params);
        verifyCctpReceiverDeployment(deployment.receiver, deployment.executor, cctpMessageTransmitter);
    }

    function verifyExecutorDeployment(
        Deployment     memory deployment,
        ExecutorParams memory params
    ) internal view {
        Executor executor = Executor(deployment.executor);

        // Executor has correct delay and grace period to default values
        require(executor.delay()       == params.delay,       "Verify/incorrect-executor-delay");
        require(executor.gracePeriod() == params.gracePeriod, "Verify/incorrect-executor-grace-period");

        // Executor has not processed any actions sets
        require(executor.actionsSetCount() == 0, "Verify/incorrect-executor-actions-set-count");

        // Executor is its own admin
        require(executor.hasRole(executor.DEFAULT_ADMIN_ROLE(), deployment.executor) == true, "Verify/executor-not-its-own-admin");

        // Executor has no roles assigned to the deployer
        require(executor.hasRole(executor.SUBMISSION_ROLE(),    deployment.deployer) == false, "Verify/deployer-has-executor-submission-role");
        require(executor.hasRole(executor.GUARDIAN_ROLE(),      deployment.deployer) == false, "Verify/deployer-has-executor-guardian-role");
        require(executor.hasRole(executor.DEFAULT_ADMIN_ROLE(), deployment.deployer) == false, "Verify/deployer-has-executor-admin-role");

        // Submissions role is correctly set to the crosschain receiver
        require(executor.hasRole(executor.SUBMISSION_ROLE(), deployment.receiver) == true, "Verify/receiver-does-not-have-executor-submission-role");
    }

    function verifyArbitrumReceiverDeployment(
        address executor,
        address receiver
    ) internal view {
        ArbitrumReceiver __receiver = ArbitrumReceiver(receiver);

        // L1 authority has to be the Ethereum Mainnet Grove Proxy
        require(__receiver.l1Authority() == Ethereum.GROVE_PROXY, "Verify/incorrect-l1-authority");

        // Target has to be the executor
        require(__receiver.target() == executor, "Verify/incorrect-target");
    }

    function verifyCctpReceiverDeployment(
        address receiver,
        address executor,
        address cctpMessageTransmitter
    ) internal view {
        CCTPReceiver __receiver = CCTPReceiver(receiver);

        // Receiver's destination messenger has to be the local cctp messenger
        require(__receiver.destinationMessenger() == cctpMessageTransmitter, "Verify/incorrect-cctp-transmitter");

        // Source domain id has to be always Ethereum Mainnet id
        require(__receiver.sourceDomainId() == 0, "Verify/incorrect-source-domain-id");

        // Source authority has to be the Ethereum Mainnet Grove Proxy
        require(__receiver.sourceAuthority() == bytes32(uint256(uint160(Ethereum.GROVE_PROXY))), "Verify/incorrect-source-authority");

        // Target has to be the executor
        require(__receiver.target() == executor, "Verify/incorrect-target");
    }

    function verifyOptimismReceiverDeployment(
        address executor,
        address receiver
    ) internal view {
        OptimismReceiver __receiver = OptimismReceiver(receiver);

        // L1 authority has to be the Ethereum Mainnet Grove Proxy
        require(__receiver.l1Authority() == Ethereum.GROVE_PROXY, "Verify/incorrect-l1-authority");

        // Target has to be the executor
        require(__receiver.target() == executor, "Verify/incorrect-target");
    }

    function verifyChainId(uint256 chainId) internal view {
        require(block.chainid == chainId, "Verify/invalid-chain-id");
    }

}
