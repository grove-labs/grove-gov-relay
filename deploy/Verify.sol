// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title  Verify
 * @notice Generic, receiver-agnostic post-deploy primitive checks.
 *
 * @dev Executor-specific verification lives in `DeployExecutor`; per-receiver verification
 *      lives in each `<X>ReceiverDeploy` library. Adding a new bridging solution should not
 *      require editing this file.
 */
library Verify {

    function verifyChainId(uint256 chainId) internal view {
        require(block.chainid == chainId, "Verify/invalid-chain-id");
    }

}
