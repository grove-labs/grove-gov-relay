// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import { LZReceiverDeploy } from "../deploy/LZReceiverDeploy.sol";

contract LZReceiverDeployHarness {

    function validate(LZReceiverDeploy.Params memory p) external view {
        LZReceiverDeploy.validate(p);
    }

    function read(string memory config) external pure returns (LZReceiverDeploy.Params memory) {
        return LZReceiverDeploy.read(config);
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

    function _withCode(string memory label) internal returns (address a) {
        a = makeAddr(label);
        vm.etch(a, hex"60006000fd");
    }

    function _baseValidParams() internal returns (LZReceiverDeploy.Params memory p) {
        p.destinationEndpoint = address(this);
        p.srcEid              = 1;
        p.sourceAuthority     = makeAddr("auth");
        p.delegate            = address(1);
        p.owner               = address(1);

        p.ulnConfig.confirmations        = 1;
        p.ulnConfig.requiredDVNs         = new address[](1);
        p.ulnConfig.requiredDVNs[0]      = _withCode("dvn");
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

    function _ulnConfigJson(uint256 confirmations, uint256 optionalDVNThreshold)
        internal
        pure
        returns (string memory)
    {
        return string.concat(
            '"ulnConfig":{'
                '"confirmations":',          vm.toString(confirmations),         ','
                '"requiredDVNs":["0x282b3386571f7f794450d5789911a9804FA346b4"],'
                '"optionalDVNs":[],'
                '"optionalDVNThreshold":',   vm.toString(optionalDVNThreshold),
            '}'
        );
    }

    function _lzConfigJson(uint256 srcEid, uint256 confirmations, uint256 optionalDVNThreshold)
        internal
        pure
        returns (string memory)
    {
        return string.concat(
            '{"executor":{"delay":0,"gracePeriod":86400},'
            '"receiver":{'
                '"destinationEndpoint":"0x6F475642a6e85809B1c36Fa62763669b1b48DD5B",'
                '"srcEid":',             vm.toString(srcEid), ','
                '"sourceAuthority":"0x1369f7b2b38c76B6478c0f0E66D94923421891Ba",'
                '"delegate":"0x0000000000000000000000000000000000000001",'
                '"owner":"0x0000000000000000000000000000000000000001",',
                _ulnConfigJson(confirmations, optionalDVNThreshold),
            '}}'
        );
    }

    function test_read_revertsOnSrcEidOverflow() public {
        string memory config = _lzConfigJson(uint256(type(uint32).max) + 1, 1, 0);
        vm.expectRevert("VerificationHelpers/value-exceeds-uint32: receiver.srcEid");
        harness.read(config);
    }

    function test_read_revertsOnConfirmationsOverflow() public {
        string memory config = _lzConfigJson(1, uint256(type(uint32).max) + 1, 0);
        vm.expectRevert("VerificationHelpers/value-exceeds-uint32: receiver.ulnConfig.confirmations");
        harness.read(config);
    }

    function test_read_revertsOnOptionalDVNThresholdOverflow() public {
        string memory config = _lzConfigJson(1, 1, uint256(type(uint8).max) + 1);
        vm.expectRevert("VerificationHelpers/value-exceeds-uint8: receiver.ulnConfig.optionalDVNThreshold");
        harness.read(config);
    }

    function test_validate_revertsOnZeroAddressInRequiredDVNs() public {
        LZReceiverDeploy.Params memory p = _baseValidParams();
        p.ulnConfig.requiredDVNs    = new address[](2);
        p.ulnConfig.requiredDVNs[0] = _withCode("dvn0");
        p.ulnConfig.requiredDVNs[1] = address(0);

        vm.expectRevert("VerificationHelpers/zero-address: receiver.ulnConfig.requiredDVNs[1]");
        harness.validate(p);
    }

    function test_validate_revertsOnEoaInRequiredDVNs() public {
        LZReceiverDeploy.Params memory p = _baseValidParams();
        p.ulnConfig.requiredDVNs    = new address[](1);
        p.ulnConfig.requiredDVNs[0] = makeAddr("eoa-dvn");

        vm.expectRevert("VerificationHelpers/no-code-at-address: receiver.ulnConfig.requiredDVNs[0]");
        harness.validate(p);
    }

    function test_validate_revertsOnZeroAddressInOptionalDVNs() public {
        LZReceiverDeploy.Params memory p = _baseValidParams();
        p.ulnConfig.optionalDVNs         = new address[](1);
        p.ulnConfig.optionalDVNs[0]      = address(0);
        p.ulnConfig.optionalDVNThreshold = 1;

        vm.expectRevert("VerificationHelpers/zero-address: receiver.ulnConfig.optionalDVNs[0]");
        harness.validate(p);
    }

    function test_validate_revertsOnEoaInOptionalDVNs() public {
        LZReceiverDeploy.Params memory p = _baseValidParams();
        p.ulnConfig.optionalDVNs         = new address[](1);
        p.ulnConfig.optionalDVNs[0]      = makeAddr("eoa-optional-dvn");
        p.ulnConfig.optionalDVNThreshold = 1;

        vm.expectRevert("VerificationHelpers/no-code-at-address: receiver.ulnConfig.optionalDVNs[0]");
        harness.validate(p);
    }

    function test_validate_revertsOnOptionalThresholdExceedsOptionalDVNs() public {
        LZReceiverDeploy.Params memory p = _baseValidParams();
        p.ulnConfig.optionalDVNs         = new address[](1);
        p.ulnConfig.optionalDVNs[0]      = _withCode("opt-dvn");
        p.ulnConfig.optionalDVNThreshold = 2;  // > optionalDVNs.length (1)

        vm.expectRevert("LZReceiverDeploy/optional-threshold-exceeds-optional-DVNs");
        harness.validate(p);
    }

    function test_validate_passesOnOptionalDVNsOnly() public {
        // Lock in the "no required DVNs, only optional with a non-zero threshold" shape -
        // a regression that disallowed this configuration would otherwise pass the suite.
        LZReceiverDeploy.Params memory p = _baseValidParams();
        p.ulnConfig.requiredDVNs         = new address[](0);
        p.ulnConfig.optionalDVNs         = new address[](2);
        p.ulnConfig.optionalDVNs[0]      = _withCode("opt-dvn-0");
        p.ulnConfig.optionalDVNs[1]      = _withCode("opt-dvn-1");
        p.ulnConfig.optionalDVNThreshold = 2;

        harness.validate(p);
    }

}
