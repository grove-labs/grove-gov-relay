// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import { StdChains } from "forge-std/StdChains.sol";

import { BaseDeployScript } from "../script/BaseDeployScript.sol";

/**
 * @notice Concrete instance so we can call internal helpers externally for assertions.
 *         `selectChain` is not unit-tested because its tail calls `vm.createSelectFork`
 *         (requires a real RPC); the testable resolution kernel
 *         `resolveChainFromInputs` is exercised here directly with plain arguments,
 *         avoiding `vm.setEnv` cross-test contamination.
 */
contract BaseDeployScriptHarness is BaseDeployScript {

    function callSetUpNonStandardChains() external {
        setUpNonStandardChains();
    }

    function callResolveChainFromInputs(
        string memory chainName,
        string memory adHocRpc,
        uint256       adHocId
    ) external returns (StdChains.Chain memory) {
        return resolveChainFromInputs(chainName, adHocRpc, adHocId);
    }

    function readChain(string memory alias_) external returns (StdChains.Chain memory) {
        return getChain(alias_);
    }

    function setChainHarness(string memory alias_, StdChains.ChainData memory c) external {
        setChain(alias_, c);
    }

}

contract BaseDeployScriptTests is Test {

    BaseDeployScriptHarness harness;

    function setUp() public {
        harness = new BaseDeployScriptHarness();
    }

    /**********************************************************************************************/
    /*** Tier 2: pre-registered non-standard chains                                             ***/
    /**********************************************************************************************/

    function test_setUpNonStandardChains_registersPlume() public {
        vm.setEnv("PLUME_RPC_URL", "https://stub.plume.example");

        harness.callSetUpNonStandardChains();

        StdChains.Chain memory c = harness.readChain("plume");
        assertEq(c.chainId, 98866);
        assertEq(c.name,    "Plume");
        assertEq(c.rpcUrl,  "https://stub.plume.example");
    }

    function test_setUpNonStandardChains_registersMonad() public {
        vm.setEnv("MONAD_RPC_URL", "https://stub.monad.example");

        harness.callSetUpNonStandardChains();

        StdChains.Chain memory c = harness.readChain("monad");
        assertEq(c.chainId, 143);
        assertEq(c.name,    "Monad");
        assertEq(c.rpcUrl,  "https://stub.monad.example");
    }

    function test_setUpNonStandardChains_registersPlasma() public {
        vm.setEnv("PLASMA_RPC_URL", "https://stub.plasma.example");

        harness.callSetUpNonStandardChains();

        StdChains.Chain memory c = harness.readChain("plasma");
        assertEq(c.chainId, 9745);
        assertEq(c.name,    "Plasma");
        assertEq(c.rpcUrl,  "https://stub.plasma.example");
    }

    /**********************************************************************************************/
    /*** Tier 3: ad-hoc setChain primitive                                                      ***/
    /**********************************************************************************************/

    function test_setChain_registersAdHocChain() public {
        StdChains.ChainData memory input = StdChains.ChainData({
            name    : "newchain",
            chainId : 99999,
            rpcUrl  : "https://stub.newchain.example"
        });
        harness.setChainHarness("newchain", input);

        StdChains.Chain memory got = harness.readChain("newchain");
        assertEq(got.chainId,    99999);
        assertEq(got.name,       "newchain");
        assertEq(got.chainAlias, "newchain");
        assertEq(got.rpcUrl,     "https://stub.newchain.example");
    }

    /**********************************************************************************************/
    /*** resolveChainFromInputs: env-var combinations & error paths                             ***/
    /**********************************************************************************************/

    function test_resolveChain_revertsOnMissingChain() public {
        vm.expectRevert(
            "BaseDeployScript/missing-CHAIN-env-var: set CHAIN=<alias> (see Makefile header for tier 1/2/3 examples)"
        );
        harness.callResolveChainFromInputs("", "", 0);
    }

    function test_resolveChain_revertsOnPartialAdHocRpcOnly() public {
        vm.expectRevert(
            "BaseDeployScript/partial-ad-hoc-chain: set both CHAIN_RPC_URL and CHAIN_ID, or neither"
        );
        harness.callResolveChainFromInputs("newchain", "https://stub.newchain.example", 0);
    }

    function test_resolveChain_revertsOnPartialAdHocIdOnly() public {
        vm.expectRevert(
            "BaseDeployScript/partial-ad-hoc-chain: set both CHAIN_RPC_URL and CHAIN_ID, or neither"
        );
        harness.callResolveChainFromInputs("newchain", "", 99999);
    }

    function test_resolveChain_revertsOnUnknownChainWithoutRpcUrl() public {
        // Tier-2 chain (plume) with no PLUME_RPC_URL env var and no ad-hoc override.
        // forge-std's getChain surfaces this with "invalid rpc url: <alias>".
        vm.setEnv("PLUME_RPC_URL", "");
        vm.expectRevert("invalid rpc url: plume");
        harness.callResolveChainFromInputs("plume", "", 0);
    }

    function test_resolveChain_resolvesTier2Chain() public {
        vm.setEnv("MONAD_RPC_URL", "https://stub.monad.example");

        StdChains.Chain memory c = harness.callResolveChainFromInputs("monad", "", 0);
        assertEq(c.chainAlias, "monad");
        assertEq(c.chainId,    143);
        assertEq(c.rpcUrl,     "https://stub.monad.example");
    }

    function test_resolveChain_resolvesAdHocTier3Chain() public {
        StdChains.Chain memory c = harness.callResolveChainFromInputs(
            "newchain",
            "https://stub.newchain.example",
            99999
        );
        assertEq(c.chainAlias, "newchain");
        assertEq(c.chainId,    99999);
        assertEq(c.rpcUrl,     "https://stub.newchain.example");
    }

}
