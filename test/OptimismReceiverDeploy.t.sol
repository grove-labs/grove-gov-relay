// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import { OptimismReceiverDeploy } from "../deploy/OptimismReceiverDeploy.sol";

contract OptimismReceiverDeployHarness {

    function validate(OptimismReceiverDeploy.Params memory p) external pure {
        OptimismReceiverDeploy.validate(p);
    }

}

contract OptimismReceiverDeployTests is Test {

    OptimismReceiverDeployHarness harness;

    function setUp() public {
        harness = new OptimismReceiverDeployHarness();
    }

    function _readExample() internal view returns (string memory config) {
        string memory path = string.concat(
            vm.projectRoot(),
            "/script/config/optimism.example.json"
        );
        config = vm.readFile(path);
    }

    function test_readExample() public view {
        OptimismReceiverDeploy.Params memory p = OptimismReceiverDeploy.read(_readExample());
        assertEq(p.sourceAuthority, 0x1369f7b2b38c76B6478c0f0E66D94923421891Ba);
    }

    function test_validate_passesOnNonZero() public {
        OptimismReceiverDeploy.Params memory p = OptimismReceiverDeploy.Params({
            sourceAuthority: makeAddr("sourceAuthority")
        });
        harness.validate(p);
    }

    function test_validate_revertsOnZero() public {
        OptimismReceiverDeploy.Params memory p = OptimismReceiverDeploy.Params({
            sourceAuthority: address(0)
        });
        vm.expectRevert("VerificationHelpers/zero-address: receiver.sourceAuthority");
        harness.validate(p);
    }

}
