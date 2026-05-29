// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import { ArbitrumReceiverDeploy } from "../deploy/ArbitrumReceiverDeploy.sol";

contract ArbitrumReceiverDeployHarness {

    function validate(ArbitrumReceiverDeploy.Params memory p) external pure {
        ArbitrumReceiverDeploy.validate(p);
    }

}

contract ArbitrumReceiverDeployTests is Test {

    ArbitrumReceiverDeployHarness harness;

    function setUp() public {
        harness = new ArbitrumReceiverDeployHarness();
    }

    function _readExample() internal view returns (string memory config) {
        string memory path = string.concat(
            vm.projectRoot(),
            "/script/config/arbitrum.example.json"
        );
        config = vm.readFile(path);
    }

    function test_readExample() public view {
        ArbitrumReceiverDeploy.Params memory p = ArbitrumReceiverDeploy.read(_readExample());
        assertEq(p.sourceAuthority, 0x1369f7b2b38c76B6478c0f0E66D94923421891Ba);
    }

    function test_validate_passesOnNonZero() public {
        ArbitrumReceiverDeploy.Params memory p = ArbitrumReceiverDeploy.Params({
            sourceAuthority: makeAddr("sourceAuthority")
        });
        harness.validate(p);
    }

    function test_validate_revertsOnZero() public {
        ArbitrumReceiverDeploy.Params memory p = ArbitrumReceiverDeploy.Params({
            sourceAuthority: address(0)
        });
        vm.expectRevert("VerificationHelpers/zero-address: receiver.sourceAuthority");
        harness.validate(p);
    }

}
