// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { stdJson } from "forge-std/StdJson.sol";

import { UlnConfig } from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";

import { LZReceiver } from "lib/xchain-helpers/src/receivers/LZReceiver.sol";

import { DeployExecutor }      from "./DeployExecutor.sol";
import { VerificationHelpers } from "./VerificationHelpers.sol";

interface ILayerZeroEndpointV2Like {
    function delegates(address sender) external view returns (address);
}

/**
 * @title  LZReceiverDeploy
 * @notice All LayerZero-receiver-specific deployment configuration, validation and verification.
 */
library LZReceiverDeploy {

    using stdJson for string;

    struct Params {
        address                   destinationEndpoint;
        uint32                    srcEid;
        address                   sourceAuthority;
        address                   delegate;
        address                   owner;
        LZReceiver.UlConfigParams ulnConfig;
    }

    function read(string memory config) internal pure returns (Params memory p) {
        p.destinationEndpoint = config.readAddress(".receiver.destinationEndpoint");
        p.srcEid              = VerificationHelpers.requireFitsUint32(
            config.readUint(".receiver.srcEid"),
            "receiver.srcEid"
        );
        p.sourceAuthority     = config.readAddress(".receiver.sourceAuthority");
        p.delegate            = config.readAddress(".receiver.delegate");
        p.owner               = config.readAddress(".receiver.owner");

        p.ulnConfig = LZReceiver.UlConfigParams({
            confirmations        : VerificationHelpers.requireFitsUint32(
                config.readUint(".receiver.ulnConfig.confirmations"),
                "receiver.ulnConfig.confirmations"
            ),
            requiredDVNs         : config.readAddressArray(".receiver.ulnConfig.requiredDVNs"),
            optionalDVNs         : config.readAddressArray(".receiver.ulnConfig.optionalDVNs"),
            optionalDVNThreshold : VerificationHelpers.requireFitsUint8(
                config.readUint(".receiver.ulnConfig.optionalDVNThreshold"),
                "receiver.ulnConfig.optionalDVNThreshold"
            )
        });
    }

    function validate(Params memory p) internal view {
        VerificationHelpers.requireHasCode(p.destinationEndpoint, "receiver.destinationEndpoint");
        VerificationHelpers.requireNonZero(p.sourceAuthority,     "receiver.sourceAuthority");
        VerificationHelpers.requireNonZero(p.delegate,            "receiver.delegate");
        VerificationHelpers.requireNonZero(p.owner,               "receiver.owner");
        require(p.srcEid != 0, "LZReceiverDeploy/zero-srcEid");
        require(
            p.ulnConfig.requiredDVNs.length > 0
            || (p.ulnConfig.optionalDVNs.length > 0 && p.ulnConfig.optionalDVNThreshold > 0),
            "LZReceiverDeploy/no-DVNs-configured"
        );
        require(
            p.ulnConfig.optionalDVNThreshold <= p.ulnConfig.optionalDVNs.length,
            "LZReceiverDeploy/optional-threshold-exceeds-optional-DVNs"
        );
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
        LZReceiver __receiver = LZReceiver(receiver);

        bytes32 expectedSourceAuthorityBytes32 = bytes32(uint256(uint160(receiverParams.sourceAuthority)));

        require(address(__receiver.endpoint()) == receiverParams.destinationEndpoint, "LZReceiverDeploy/incorrect-destination-endpoint");
        require(__receiver.srcEid()            == receiverParams.srcEid,              "LZReceiverDeploy/incorrect-src-eid");
        require(__receiver.sourceAuthority()   == expectedSourceAuthorityBytes32,     "LZReceiverDeploy/incorrect-source-authority");
        require(__receiver.target()            == executor,                           "LZReceiverDeploy/incorrect-target");

        require(
            ILayerZeroEndpointV2Like(address(__receiver.endpoint())).delegates(address(__receiver)) == receiverParams.delegate,
            "LZReceiverDeploy/incorrect-delegate"
        );

        require(__receiver.owner() == receiverParams.owner, "LZReceiverDeploy/incorrect-owner");

        ( address receiveLib, ) = __receiver.endpoint().getReceiveLibrary(
            address(__receiver),
            __receiver.srcEid()
        );

        bytes memory configBytes = __receiver.endpoint().getConfig(
            address(__receiver),
            receiveLib,
            __receiver.srcEid(),
            2  // configType 2 is for UlnConfig
        );

        UlnConfig memory ulnConfig = abi.decode(configBytes, (UlnConfig));

        require(ulnConfig.confirmations        == receiverParams.ulnConfig.confirmations,        "LZReceiverDeploy/incorrect-confirmations");
        require(ulnConfig.requiredDVNCount     == receiverParams.ulnConfig.requiredDVNs.length,  "LZReceiverDeploy/incorrect-requiredDVNCount");
        require(ulnConfig.optionalDVNCount     == receiverParams.ulnConfig.optionalDVNs.length,  "LZReceiverDeploy/incorrect-optionalDVNCount");
        require(ulnConfig.optionalDVNThreshold == receiverParams.ulnConfig.optionalDVNThreshold, "LZReceiverDeploy/incorrect-optionalDVNThreshold");
        require(ulnConfig.requiredDVNs.length  == receiverParams.ulnConfig.requiredDVNs.length,  "LZReceiverDeploy/incorrect-requiredDVNs-length");
        require(ulnConfig.optionalDVNs.length  == receiverParams.ulnConfig.optionalDVNs.length,  "LZReceiverDeploy/incorrect-optionalDVNs-length");

        for (uint256 i = 0; i < receiverParams.ulnConfig.requiredDVNs.length; i++) {
            require(ulnConfig.requiredDVNs[i] == receiverParams.ulnConfig.requiredDVNs[i], "LZReceiverDeploy/incorrect-requiredDVN");
        }

        for (uint256 i = 0; i < receiverParams.ulnConfig.optionalDVNs.length; i++) {
            require(ulnConfig.optionalDVNs[i] == receiverParams.ulnConfig.optionalDVNs[i], "LZReceiverDeploy/incorrect-optionalDVN");
        }
    }

}
