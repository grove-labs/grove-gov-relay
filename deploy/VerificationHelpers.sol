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
        require(a != address(0), string.concat("VerificationHelpers/zero-address: ", name));

        bytes memory code = a.code;
        require(code.length != 0, string.concat("VerificationHelpers/no-code-at-address: ", name));

        // EIP-7702 (Pectra): an EOA that has authorised a delegate has code that begins with
        // the designator `0xef0100<delegate-20-bytes>`. `0xef` is a reserved opcode (EIP-3541),
        // so any post-3541 contract bytecode cannot start with it - a `code[0] == 0xef` here
        // unambiguously means a delegated EOA, not a real contract. Reject it: callers of this
        // helper want an actual deployed contract, not an EOA pretending to be one via 7702.
        require(
            code.length < 3 || !(code[0] == 0xef && code[1] == 0x01 && code[2] == 0x00),
            string.concat("VerificationHelpers/eip-7702-delegated-eoa: ", name)
        );
    }

    function requireFitsUint32(uint256 v, string memory name) internal pure returns (uint32) {
        require(v <= type(uint32).max, string.concat("VerificationHelpers/value-exceeds-uint32: ", name));
        return uint32(v);
    }

    function requireFitsUint8(uint256 v, string memory name) internal pure returns (uint8) {
        require(v <= type(uint8).max, string.concat("VerificationHelpers/value-exceeds-uint8: ", name));
        return uint8(v);
    }

}
