// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { DeployConfig } from "./DeployConfig.sol";

import { Executor } from "src/Executor.sol";

/**
 * @title  VerificationHelpers
 * @notice Pre-deployment input validation for the deploy scripts.
 *
 * @dev Pulled out of `DeployConfig` so that the config library only handles loading and
 *      parsing, while authority/parameter checks live alongside the rest of the verification
 *      logic.
 */
library VerificationHelpers {

    /**********************************************************************************************/
    /*** Primitive helpers                                                                      ***/
    /**********************************************************************************************/

    function requireNonZero(address a, string memory name) internal pure {
        require(a != address(0), string.concat("VerificationHelpers/zero-address: ", name));
    }

    function requireZero(address a, string memory name) internal pure {
        require(a == address(0), string.concat("VerificationHelpers/expected-unset-address: ", name));
    }

    function requireHasCode(address a, string memory name) internal view {
        require(a != address(0),    string.concat("VerificationHelpers/zero-address: ",        name));
        require(a.code.length != 0, string.concat("VerificationHelpers/no-code-at-address: ", name));
    }

    /**********************************************************************************************/
    /*** Receiver-type-specific input checks                                                    ***/
    /**********************************************************************************************/

    function validateExecutorParams(DeployConfig.ExecutorParams memory p, bool requireExisting) internal view {
        if (requireExisting) {
            requireHasCode(p.existingAddress, "executor.address");

            Executor existing = Executor(p.existingAddress);
            require(
                existing.delay() == p.delay,
                "VerificationHelpers/executor-delay-mismatch"
            );
            require(
                existing.gracePeriod() == p.gracePeriod,
                "VerificationHelpers/executor-grace-period-mismatch"
            );
        } else {
            requireZero(p.existingAddress, "executor.address");
            // delay/gracePeriod are intentionally not constrained here; arbitrary values are valid.
        }
    }

    function validateSourceAuthority(address sourceAuthority) internal pure {
        requireNonZero(sourceAuthority, "receiver.sourceAuthority");
    }

    function validateAMBReceiverParams(DeployConfig.AMBReceiverParams memory p) internal view {
        requireHasCode(p.amb,             "receiver.amb");
        requireNonZero(p.sourceAuthority, "receiver.sourceAuthority");
        require(p.sourceChainId != bytes32(0), "VerificationHelpers/zero-sourceChainId");
    }

    function validateCctpReceiverParams(DeployConfig.CctpReceiverParams memory p) internal view {
        requireHasCode(p.destinationMessenger, "receiver.destinationMessenger");
        requireNonZero(p.sourceAuthority,      "receiver.sourceAuthority");
    }

    function validateLZReceiverParams(DeployConfig.LZReceiverParams memory p) internal view {
        requireHasCode(p.destinationEndpoint, "receiver.destinationEndpoint");
        requireNonZero(p.sourceAuthority,     "receiver.sourceAuthority");
        requireNonZero(p.delegate,            "receiver.delegate");
        requireNonZero(p.owner,               "receiver.owner");
        require(p.srcEid != 0, "VerificationHelpers/zero-srcEid");
        require(
            p.ulnConfig.requiredDVNs.length > 0
            || (p.ulnConfig.optionalDVNs.length > 0 && p.ulnConfig.optionalDVNThreshold > 0),
            "VerificationHelpers/no-DVNs-configured"
        );
        require(
            p.ulnConfig.optionalDVNThreshold <= p.ulnConfig.optionalDVNs.length,
            "VerificationHelpers/optional-threshold-exceeds-optional-DVNs"
        );
    }

}
