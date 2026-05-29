// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import { CCTPv2ReceiverDeploy } from "../deploy/CCTPv2ReceiverDeploy.sol";

contract CCTPv2ReceiverDeployHarness {

    function validate(CCTPv2ReceiverDeploy.Params memory p) external view {
        CCTPv2ReceiverDeploy.validate(p);
    }

    function read(string memory config) external pure returns (CCTPv2ReceiverDeploy.Params memory) {
        return CCTPv2ReceiverDeploy.read(config);
    }

}

contract CCTPv2ReceiverDeployTests is Test {

    CCTPv2ReceiverDeployHarness harness;

    function setUp() public {
        harness = new CCTPv2ReceiverDeployHarness();
    }

    function _readExample() internal view returns (string memory config) {
        string memory path = string.concat(
            vm.projectRoot(),
            "/script/config/cctp-v2.example.json"
        );
        config = vm.readFile(path);
    }

    function test_readExample() public view {
        CCTPv2ReceiverDeploy.Params memory p = CCTPv2ReceiverDeploy.read(_readExample());
        assertEq(p.destinationMessenger, 0x81D40F21F12A8F0E3252Bccb954D722d4c464B64);
        assertEq(p.sourceDomainId,       0);
        assertEq(p.sourceAuthority,      0x1369f7b2b38c76B6478c0f0E66D94923421891Ba);
    }

    function test_validate_revertsOnZeroAuthority() public {
        CCTPv2ReceiverDeploy.Params memory p = CCTPv2ReceiverDeploy.Params({
            destinationMessenger : address(this),
            sourceDomainId       : 0,
            sourceAuthority      : address(0)
        });
        vm.expectRevert("VerificationHelpers/zero-address: receiver.sourceAuthority");
        harness.validate(p);
    }

    function test_validate_revertsOnMessengerWithoutCode() public {
        CCTPv2ReceiverDeploy.Params memory p = CCTPv2ReceiverDeploy.Params({
            destinationMessenger : makeAddr("messenger"),
            sourceDomainId       : 0,
            sourceAuthority      : makeAddr("auth")
        });
        vm.expectRevert("VerificationHelpers/no-code-at-address: receiver.destinationMessenger");
        harness.validate(p);
    }

    function test_read_revertsOnSourceDomainIdOverflow() public {
        // 2**32 (uint32.max + 1) silently truncates to 0 without the range check.
        string memory config =
            '{"executor":{"delay":0,"gracePeriod":86400},'
            '"receiver":{'
                '"destinationMessenger":"0x81D40F21F12A8F0E3252Bccb954D722d4c464B64",'
                '"sourceDomainId":4294967296,'
                '"sourceAuthority":"0x1369f7b2b38c76B6478c0f0E66D94923421891Ba"'
            '}}';

        vm.expectRevert("VerificationHelpers/value-exceeds-uint32: receiver.sourceDomainId");
        harness.read(config);
    }

}
