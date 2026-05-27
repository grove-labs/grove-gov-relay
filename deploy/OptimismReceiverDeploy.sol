// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { stdJson } from "forge-std/StdJson.sol";

import { OptimismReceiver } from "lib/xchain-helpers/src/receivers/OptimismReceiver.sol";

import { DeployExecutor }      from "./DeployExecutor.sol";
import { VerificationHelpers } from "./VerificationHelpers.sol";

/**
 * @title  OptimismReceiverDeploy
 * @notice All Optimism-receiver-specific deployment configuration, validation and verification.
 */
library OptimismReceiverDeploy {

    using stdJson for string;

    struct Params {
        address sourceAuthority;
    }

    function read(string memory config) internal pure returns (Params memory p) {
        p.sourceAuthority = config.readAddress(".receiver.sourceAuthority");
    }

    function validate(Params memory p) internal pure {
        VerificationHelpers.requireNonZero(p.sourceAuthority, "receiver.sourceAuthority");
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
        OptimismReceiver __receiver = OptimismReceiver(receiver);

        require(
            __receiver.l1Authority() == receiverParams.sourceAuthority,
            "OptimismReceiverDeploy/incorrect-source-authority"
        );
        require(
            __receiver.target() == executor,
            "OptimismReceiverDeploy/incorrect-target"
        );
    }

}
