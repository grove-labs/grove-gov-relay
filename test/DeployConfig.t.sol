// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import { Executor } from "../src/Executor.sol";

import { DeployConfig }        from "../deploy/DeployConfig.sol";
import { VerificationHelpers } from "../deploy/VerificationHelpers.sol";

// Wrapper that re-exposes library functions externally so vm.expectRevert can observe reverts.
contract DeployConfigHarness {

    function loadConfig() external returns (string memory) {
        return DeployConfig.loadConfig();
    }

    function validateExecutorParams(DeployConfig.ExecutorParams memory ep, bool requireExisting) external view {
        VerificationHelpers.validateExecutorParams(ep, requireExisting);
    }

    function validateSourceAuthority(address authority) external pure {
        VerificationHelpers.validateSourceAuthority(authority);
    }

    function validateAMBReceiverParams(DeployConfig.AMBReceiverParams memory rp) external view {
        VerificationHelpers.validateAMBReceiverParams(rp);
    }

    function validateCctpReceiverParams(DeployConfig.CctpReceiverParams memory rp) external view {
        VerificationHelpers.validateCctpReceiverParams(rp);
    }

    function validateLZReceiverParams(DeployConfig.LZReceiverParams memory rp) external view {
        VerificationHelpers.validateLZReceiverParams(rp);
    }

}

contract DeployConfigTests is Test {

    DeployConfigHarness harness;

    function setUp() public {
        harness = new DeployConfigHarness();
    }

    function _readExample(string memory slug) internal view returns (string memory config) {
        string memory path = string.concat(
            vm.projectRoot(),
            "/script/config/",
            slug,
            ".example.json"
        );
        config = vm.readFile(path);
    }

    function test_readArbitrumExample() public view {
        string memory config = _readExample("arbitrum");

        DeployConfig.ExecutorParams memory ep = DeployConfig.readExecutorParams(config);
        assertEq(ep.existingAddress, address(0));
        assertEq(ep.delay,           0);
        assertEq(ep.gracePeriod,     7 days);

        address sourceAuthority = DeployConfig.readSourceAuthority(config);
        assertEq(sourceAuthority, 0x1369f7b2b38c76B6478c0f0E66D94923421891Ba);
    }

    function test_readOptimismExample() public view {
        string memory config = _readExample("optimism");

        DeployConfig.ExecutorParams memory ep = DeployConfig.readExecutorParams(config);
        assertEq(ep.existingAddress, address(0));
        assertEq(ep.delay,           0);
        assertEq(ep.gracePeriod,     7 days);

        address sourceAuthority = DeployConfig.readSourceAuthority(config);
        assertEq(sourceAuthority, 0x1369f7b2b38c76B6478c0f0E66D94923421891Ba);
    }

    function test_readCctpV2Example() public view {
        string memory config = _readExample("cctp-v2");

        DeployConfig.ExecutorParams memory ep = DeployConfig.readExecutorParams(config);
        assertEq(ep.existingAddress, address(0));

        DeployConfig.CctpReceiverParams memory rp = DeployConfig.readCctpReceiverParams(config);
        assertEq(rp.destinationMessenger, 0x81D40F21F12A8F0E3252Bccb954D722d4c464B64);
        assertEq(rp.sourceDomainId,       0);
        assertEq(rp.sourceAuthority,      0x1369f7b2b38c76B6478c0f0E66D94923421891Ba);
    }

    function test_readAMBExample() public view {
        string memory config = _readExample("amb");

        DeployConfig.ExecutorParams memory ep = DeployConfig.readExecutorParams(config);
        assertEq(ep.existingAddress, address(0));
        assertEq(ep.delay,           0);
        assertEq(ep.gracePeriod,     7 days);

        DeployConfig.AMBReceiverParams memory rp = DeployConfig.readAMBReceiverParams(config);
        assertEq(rp.amb,             0x75Df5AF045d91108662D8080fD1FEFAd6aA0bb59);
        assertEq(rp.sourceChainId,   bytes32(uint256(1)));
        assertEq(rp.sourceAuthority, 0x1369f7b2b38c76B6478c0f0E66D94923421891Ba);
    }

    function test_readLZExample() public view {
        string memory config = _readExample("lz");

        DeployConfig.LZReceiverParams memory rp = DeployConfig.readLZReceiverParams(config);
        assertEq(rp.destinationEndpoint, 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B);
        assertEq(rp.srcEid,              30101);
        assertEq(rp.sourceAuthority,     0x1369f7b2b38c76B6478c0f0E66D94923421891Ba);
        assertEq(rp.delegate,            address(1));
        assertEq(rp.owner,               address(1));

        assertEq(rp.ulnConfig.confirmations,           15);
        assertEq(rp.ulnConfig.requiredDVNs.length,     2);
        assertEq(rp.ulnConfig.requiredDVNs[0],         0x282b3386571f7f794450d5789911a9804FA346b4);
        assertEq(rp.ulnConfig.requiredDVNs[1],         0xa51cE237FaFA3052D5d3308Df38A024724Bb1274);
        assertEq(rp.ulnConfig.optionalDVNs.length,     0);
        assertEq(rp.ulnConfig.optionalDVNThreshold,    0);
    }

    // NOTE: vm.setEnv mutates a process-global env var, so this test bundles the three
    //       CONFIG cases sequentially in one test to avoid races with parallel runners.
    function test_loadConfig_envVarBehaviour() public {
        // 1. Empty CONFIG -> dedicated revert.
        vm.setEnv("CONFIG", "");
        vm.expectRevert("DeployConfig/missing-CONFIG-env-var: set CONFIG=<slug> for script/config/<slug>.json");
        harness.loadConfig();

        // 2. Nonexistent slug -> verbose output and config-not-found revert.
        vm.setEnv("CONFIG", "definitely-does-not-exist");
        vm.expectRevert("DeployConfig/config-not-found: definitely-does-not-exist.json");
        harness.loadConfig();

        // 3. Valid slug -> file is loaded, non-empty content returned.
        vm.setEnv("CONFIG", "amb.example");
        string memory config = harness.loadConfig();
        assertTrue(bytes(config).length > 0);
    }

    /**********************************************************************************************/
    /*** VerificationHelpers validation                                                         ***/
    /**********************************************************************************************/

    function test_validateExecutorParams_full_zeroAddress() public view {
        DeployConfig.ExecutorParams memory ep = DeployConfig.ExecutorParams({
            existingAddress: address(0),
            delay:           0,
            gracePeriod:     1
        });
        harness.validateExecutorParams(ep, false);
    }

    function test_validateExecutorParams_full_revertsOnNonZero() public {
        DeployConfig.ExecutorParams memory ep = DeployConfig.ExecutorParams({
            existingAddress: makeAddr("executor"),
            delay:           0,
            gracePeriod:     1
        });
        vm.expectRevert("VerificationHelpers/expected-unset-address: executor.address");
        harness.validateExecutorParams(ep, false);
    }

    function test_validateExecutorParams_receiverOnly_revertsOnZero() public {
        DeployConfig.ExecutorParams memory ep = DeployConfig.ExecutorParams({
            existingAddress: address(0),
            delay:           0,
            gracePeriod:     1
        });
        vm.expectRevert("VerificationHelpers/zero-address: executor.address");
        harness.validateExecutorParams(ep, true);
    }

    function test_validateExecutorParams_receiverOnly_revertsOnNoCode() public {
        DeployConfig.ExecutorParams memory ep = DeployConfig.ExecutorParams({
            existingAddress: makeAddr("executor"),
            delay:           0,
            gracePeriod:     1
        });
        vm.expectRevert("VerificationHelpers/no-code-at-address: executor.address");
        harness.validateExecutorParams(ep, true);
    }

    function test_validateExecutorParams_receiverOnly_passesOnMatchingLiveExecutor() public {
        Executor existing = new Executor(1 hours, 7 days);
        DeployConfig.ExecutorParams memory ep = DeployConfig.ExecutorParams({
            existingAddress: address(existing),
            delay:           1 hours,
            gracePeriod:     7 days
        });
        harness.validateExecutorParams(ep, true);
    }

    function test_validateExecutorParams_receiverOnly_revertsOnDelayMismatch() public {
        Executor existing = new Executor(1 hours, 7 days);
        DeployConfig.ExecutorParams memory ep = DeployConfig.ExecutorParams({
            existingAddress: address(existing),
            delay:           2 hours,
            gracePeriod:     7 days
        });
        vm.expectRevert("VerificationHelpers/executor-delay-mismatch");
        harness.validateExecutorParams(ep, true);
    }

    function test_validateExecutorParams_receiverOnly_revertsOnGracePeriodMismatch() public {
        Executor existing = new Executor(1 hours, 7 days);
        DeployConfig.ExecutorParams memory ep = DeployConfig.ExecutorParams({
            existingAddress: address(existing),
            delay:           1 hours,
            gracePeriod:     14 days
        });
        vm.expectRevert("VerificationHelpers/executor-grace-period-mismatch");
        harness.validateExecutorParams(ep, true);
    }

    function test_validateSourceAuthority_passesOnNonZero() public {
        harness.validateSourceAuthority(makeAddr("sourceAuthority"));
    }

    function test_validateSourceAuthority_revertsOnZero() public {
        vm.expectRevert("VerificationHelpers/zero-address: receiver.sourceAuthority");
        harness.validateSourceAuthority(address(0));
    }

    function test_validateAMBReceiverParams_revertsOnZeroChainId() public {
        DeployConfig.AMBReceiverParams memory rp = DeployConfig.AMBReceiverParams({
            amb:             address(this),
            sourceChainId:   bytes32(0),
            sourceAuthority: makeAddr("auth")
        });
        vm.expectRevert("VerificationHelpers/zero-sourceChainId");
        harness.validateAMBReceiverParams(rp);
    }

    function test_validateAMBReceiverParams_revertsOnZeroAuthority() public {
        DeployConfig.AMBReceiverParams memory rp = DeployConfig.AMBReceiverParams({
            amb:             address(this),
            sourceChainId:   bytes32(uint256(1)),
            sourceAuthority: address(0)
        });
        vm.expectRevert("VerificationHelpers/zero-address: receiver.sourceAuthority");
        harness.validateAMBReceiverParams(rp);
    }

    function test_validateLZReceiverParams_revertsOnNoDVNs() public {
        DeployConfig.LZReceiverParams memory rp;
        rp.destinationEndpoint = address(this);
        rp.srcEid              = 1;
        rp.sourceAuthority     = makeAddr("auth");
        rp.delegate            = address(1);
        rp.owner               = address(1);
        rp.ulnConfig.confirmations        = 1;
        rp.ulnConfig.requiredDVNs         = new address[](0);
        rp.ulnConfig.optionalDVNs         = new address[](0);
        rp.ulnConfig.optionalDVNThreshold = 0;

        vm.expectRevert("VerificationHelpers/no-DVNs-configured");
        harness.validateLZReceiverParams(rp);
    }

}
