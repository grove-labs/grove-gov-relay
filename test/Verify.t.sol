// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import { Verify } from "../deploy/Verify.sol";

contract VerifyHarness {

    function verifyChainId(uint256 chainId) external view {
        Verify.verifyChainId(chainId);
    }

}

contract VerifyTests is Test {

    VerifyHarness harness;

    function setUp() public {
        harness = new VerifyHarness();
    }

    function test_verifyChainId_passesOnMatch() public view {
        harness.verifyChainId(block.chainid);
    }

    function test_verifyChainId_revertsOnMismatch() public {
        vm.expectRevert("Verify/invalid-chain-id");
        harness.verifyChainId(block.chainid + 1);
    }

}
