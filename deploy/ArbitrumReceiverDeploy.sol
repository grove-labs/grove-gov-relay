// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { stdJson } from "forge-std/StdJson.sol";

import { ArbitrumReceiver } from "lib/xchain-helpers/src/receivers/ArbitrumReceiver.sol";

import { DeployExecutor }      from "./DeployExecutor.sol";
import { VerificationHelpers } from "./VerificationHelpers.sol";

/**
 * @title  ArbitrumReceiverDeploy
 * @notice All Arbitrum-receiver-specific deployment configuration, validation and verification.
 */
library ArbitrumReceiverDeploy {

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
        ArbitrumReceiver __receiver = ArbitrumReceiver(receiver);

        require(
            __receiver.l1Authority() == receiverParams.sourceAuthority,
            "ArbitrumReceiverDeploy/incorrect-source-authority"
        );
        require(
            __receiver.target() == executor,
            "ArbitrumReceiverDeploy/incorrect-target"
        );
    }

}
