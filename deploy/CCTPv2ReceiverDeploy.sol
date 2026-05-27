// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { stdJson } from "forge-std/StdJson.sol";

import { CCTPv2Receiver } from "lib/xchain-helpers/src/receivers/CCTPv2Receiver.sol";

import { DeployExecutor }      from "./DeployExecutor.sol";
import { VerificationHelpers } from "./VerificationHelpers.sol";

/**
 * @title  CCTPv2ReceiverDeploy
 * @notice All CCTPv2-receiver-specific deployment configuration, validation and verification.
 */
library CCTPv2ReceiverDeploy {

    using stdJson for string;

    struct Params {
        address destinationMessenger;
        uint32  sourceDomainId;
        address sourceAuthority;
    }

    function read(string memory config) internal pure returns (Params memory p) {
        p.destinationMessenger = config.readAddress(".receiver.destinationMessenger");
        p.sourceDomainId       = VerificationHelpers.requireFitsUint32(
            config.readUint(".receiver.sourceDomainId"),
            "receiver.sourceDomainId"
        );
        p.sourceAuthority      = config.readAddress(".receiver.sourceAuthority");
    }

    function validate(Params memory p) internal view {
        VerificationHelpers.requireHasCode(p.destinationMessenger, "receiver.destinationMessenger");
        VerificationHelpers.requireNonZero(p.sourceAuthority,      "receiver.sourceAuthority");
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
        CCTPv2Receiver __receiver = CCTPv2Receiver(receiver);

        bytes32 expectedSourceAuthorityBytes32 = bytes32(uint256(uint160(receiverParams.sourceAuthority)));

        require(__receiver.destinationMessenger() == receiverParams.destinationMessenger, "CCTPv2ReceiverDeploy/incorrect-cctp-transmitter");
        require(__receiver.sourceDomainId()       == receiverParams.sourceDomainId,       "CCTPv2ReceiverDeploy/incorrect-source-domain-id");
        require(__receiver.sourceAuthority()      == expectedSourceAuthorityBytes32,      "CCTPv2ReceiverDeploy/incorrect-source-authority");
        require(__receiver.target()               == executor,                            "CCTPv2ReceiverDeploy/incorrect-target");
    }

}
