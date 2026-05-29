// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import { VerificationHelpers } from "../deploy/VerificationHelpers.sol";

contract VerificationHelpersHarness {

    function requireHasCode(address a, string memory name) external view {
        VerificationHelpers.requireHasCode(a, name);
    }

}

contract VerificationHelpersTests is Test {

    VerificationHelpersHarness harness;

    function setUp() public {
        harness = new VerificationHelpersHarness();
    }

    function test_requireHasCode_revertsOnZeroAddress() public {
        vm.expectRevert("VerificationHelpers/zero-address: target");
        harness.requireHasCode(address(0), "target");
    }

    function test_requireHasCode_revertsOnEoa() public {
        address eoa = makeAddr("eoa");
        vm.expectRevert("VerificationHelpers/no-code-at-address: target");
        harness.requireHasCode(eoa, "target");
    }

    function test_requireHasCode_passesOnContract() public view {
        // The harness itself is a deployed contract.
        harness.requireHasCode(address(harness), "target");
    }

    function test_requireHasCode_revertsOnEip7702DelegatedEoa() public {
        // EIP-7702 designator = 0xef0100 + 20-byte delegate address.
        address delegate = makeAddr("delegate");
        bytes memory designator = abi.encodePacked(hex"ef0100", delegate);
        assertEq(designator.length, 23);

        address delegatedEoa = makeAddr("delegated-eoa");
        vm.etch(delegatedEoa, designator);

        vm.expectRevert("VerificationHelpers/eip-7702-delegated-eoa: target");
        harness.requireHasCode(delegatedEoa, "target");
    }

    function test_requireHasCode_passesOnContractStartingWithNonEf() public {
        // Sanity: regular contract bytecode (anything not starting with 0xef0100) passes.
        address realish = makeAddr("realish");
        vm.etch(realish, hex"60006000fd"); // PUSH1 0; PUSH1 0; REVERT

        harness.requireHasCode(realish, "target");
    }

}
