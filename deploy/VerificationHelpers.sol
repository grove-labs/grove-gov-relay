// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

/**
 * @title  VerificationHelpers
 * @notice Generic, receiver-agnostic primitive checks used during deployment input validation.
 *
 * @dev This library is intentionally limited to address-shape primitives so that adding a
 *      new bridging solution does not require editing it. Executor-specific checks live in
 *      `DeployExecutor`; per-receiver checks live in each `<X>ReceiverDeploy` library.
 */
library VerificationHelpers {

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

}
