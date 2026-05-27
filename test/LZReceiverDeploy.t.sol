// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import { LZReceiverDeploy } from "../deploy/LZReceiverDeploy.sol";

contract LZReceiverDeployHarness {

    function validate(LZReceiverDeploy.Params memory p) external view {
        LZReceiverDeploy.validate(p);
    }

}

contract LZReceiverDeployTests is Test {

    LZReceiverDeployHarness harness;

    function setUp() public {
        harness = new LZReceiverDeployHarness();
    }

    function _readExample() internal view returns (string memory config) {
        string memory path = string.concat(
            vm.projectRoot(),
            "/script/config/lz.example.json"
        );
        config = vm.readFile(path);
    }

    function test_readExample() public view {
        LZReceiverDeploy.Params memory p = LZReceiverDeploy.read(_readExample());
        assertEq(p.destinationEndpoint, 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B);
        assertEq(p.srcEid,              30101);
        assertEq(p.sourceAuthority,     0x1369f7b2b38c76B6478c0f0E66D94923421891Ba);
        assertEq(p.delegate,            address(1));
        assertEq(p.owner,               address(1));

        assertEq(p.ulnConfig.confirmations,           15);
        assertEq(p.ulnConfig.requiredDVNs.length,     2);
        assertEq(p.ulnConfig.requiredDVNs[0],         0x282b3386571f7f794450d5789911a9804FA346b4);
        assertEq(p.ulnConfig.requiredDVNs[1],         0xa51cE237FaFA3052D5d3308Df38A024724Bb1274);
        assertEq(p.ulnConfig.optionalDVNs.length,     0);
        assertEq(p.ulnConfig.optionalDVNThreshold,    0);
    }

    function _baseValidParams() internal returns (LZReceiverDeploy.Params memory p) {
        p.destinationEndpoint = address(this);
        p.srcEid              = 1;
        p.sourceAuthority     = makeAddr("auth");
        p.delegate            = address(1);
        p.owner               = address(1);

        p.ulnConfig.confirmations        = 1;
        p.ulnConfig.requiredDVNs         = new address[](1);
        p.ulnConfig.requiredDVNs[0]      = makeAddr("dvn");
        p.ulnConfig.optionalDVNs         = new address[](0);
        p.ulnConfig.optionalDVNThreshold = 0;
    }

    function test_validate_revertsOnNoDVNs() public {
        LZReceiverDeploy.Params memory p = _baseValidParams();
        p.ulnConfig.requiredDVNs = new address[](0);

        vm.expectRevert("LZReceiverDeploy/no-DVNs-configured");
        harness.validate(p);
    }

    function test_validate_revertsOnZeroSrcEid() public {
        LZReceiverDeploy.Params memory p = _baseValidParams();
        p.srcEid = 0;

        vm.expectRevert("LZReceiverDeploy/zero-srcEid");
        harness.validate(p);
    }

    function test_validate_revertsOnZeroAuthority() public {
        LZReceiverDeploy.Params memory p = _baseValidParams();
        p.sourceAuthority = address(0);

        vm.expectRevert("VerificationHelpers/zero-address: receiver.sourceAuthority");
        harness.validate(p);
    }

    function test_validate_revertsOnZeroDelegate() public {
        LZReceiverDeploy.Params memory p = _baseValidParams();
        p.delegate = address(0);

        vm.expectRevert("VerificationHelpers/zero-address: receiver.delegate");
        harness.validate(p);
    }

}
