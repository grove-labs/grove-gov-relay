// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import { AMBReceiverDeploy } from "../deploy/AMBReceiverDeploy.sol";

contract AMBReceiverDeployHarness {

    function validate(AMBReceiverDeploy.Params memory p) external view {
        AMBReceiverDeploy.validate(p);
    }

}

contract AMBReceiverDeployTests is Test {

    AMBReceiverDeployHarness harness;

    function setUp() public {
        harness = new AMBReceiverDeployHarness();
    }

    function _readExample() internal view returns (string memory config) {
        string memory path = string.concat(
            vm.projectRoot(),
            "/script/config/amb.example.json"
        );
        config = vm.readFile(path);
    }

    function test_readExample() public view {
        AMBReceiverDeploy.Params memory p = AMBReceiverDeploy.read(_readExample());
        assertEq(p.amb,             0x75Df5AF045d91108662D8080fD1FEFAd6aA0bb59);
        assertEq(p.sourceChainId,   bytes32(uint256(1)));
        assertEq(p.sourceAuthority, 0x1369f7b2b38c76B6478c0f0E66D94923421891Ba);
    }

    function test_validate_revertsOnZeroChainId() public {
        AMBReceiverDeploy.Params memory p = AMBReceiverDeploy.Params({
            amb:             address(this),
            sourceChainId:   bytes32(0),
            sourceAuthority: makeAddr("auth")
        });
        vm.expectRevert("AMBReceiverDeploy/zero-sourceChainId");
        harness.validate(p);
    }

    function test_validate_revertsOnZeroAuthority() public {
        AMBReceiverDeploy.Params memory p = AMBReceiverDeploy.Params({
            amb:             address(this),
            sourceChainId:   bytes32(uint256(1)),
            sourceAuthority: address(0)
        });
        vm.expectRevert("VerificationHelpers/zero-address: receiver.sourceAuthority");
        harness.validate(p);
    }

    function test_validate_revertsOnAmbWithoutCode() public {
        AMBReceiverDeploy.Params memory p = AMBReceiverDeploy.Params({
            amb:             makeAddr("amb"),
            sourceChainId:   bytes32(uint256(1)),
            sourceAuthority: makeAddr("auth")
        });
        vm.expectRevert("VerificationHelpers/no-code-at-address: receiver.amb");
        harness.validate(p);
    }

}
