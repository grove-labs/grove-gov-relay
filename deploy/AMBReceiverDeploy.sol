// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { stdJson } from "forge-std/StdJson.sol";

import { AMBReceiver } from "lib/xchain-helpers/src/receivers/AMBReceiver.sol";

import { DeployExecutor }      from "./DeployExecutor.sol";
import { VerificationHelpers } from "./VerificationHelpers.sol";

/**
 * @title  AMBReceiverDeploy
 * @notice All AMB-receiver-specific deployment configuration, validation and verification.
 */
library AMBReceiverDeploy {

    using stdJson for string;

    struct Params {
        address amb;
        bytes32 sourceChainId;
        address sourceAuthority;
    }

    function read(string memory config) internal pure returns (Params memory p) {
        p.amb             = config.readAddress(".receiver.amb");
        p.sourceChainId   = bytes32(config.readUint(".receiver.sourceChainId"));
        p.sourceAuthority = config.readAddress(".receiver.sourceAuthority");
    }

    function validate(Params memory p) internal view {
        VerificationHelpers.requireHasCode(p.amb,             "receiver.amb");
        VerificationHelpers.requireNonZero(p.sourceAuthority, "receiver.sourceAuthority");
        require(p.sourceChainId != bytes32(0), "AMBReceiverDeploy/zero-sourceChainId");
    }

    function verifyFull(
        DeployExecutor.Deployment     memory deployment,
        DeployExecutor.ExecutorParams memory executorParams,
        Params                        memory receiverParams
    ) internal view {
        DeployExecutor.verifyDeployment(deployment, executorParams);
        verifyReceiverOnly(deployment.executor, deployment.receiver, receiverParams);
    }

    function verifyReceiverOnly(
        address        executor,
        address        receiver,
        Params  memory receiverParams
    ) internal view {
        AMBReceiver __receiver = AMBReceiver(receiver);

        require(__receiver.amb()             == receiverParams.amb,             "AMBReceiverDeploy/incorrect-amb");
        require(__receiver.sourceChainId()   == receiverParams.sourceChainId,   "AMBReceiverDeploy/incorrect-source-chain-id");
        require(__receiver.sourceAuthority() == receiverParams.sourceAuthority, "AMBReceiverDeploy/incorrect-source-authority");
        require(__receiver.target()          == executor,                       "AMBReceiverDeploy/incorrect-target");
    }

}
