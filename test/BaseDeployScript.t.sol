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
 *         avoiding `vm.setEnv` cross-test contamination wherever possible.
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
    /*** Pure-arg cases (env-independent, safe to interleave with parallel runners)             ***/
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

    /**********************************************************************************************/
    /*** Env-dependent cases bundled into a single sequential test                              ***/
    /**********************************************************************************************/
    /**
     * @notice All assertions that read or mutate process-global env vars (`PLUME_RPC_URL`,
     *         `MONAD_RPC_URL`, `PLASMA_RPC_URL`) are bundled into ONE sequential test to
     *         avoid order-dependent races with parallel test runners. Splitting these
     *         across separate functions risks both forge-side parallelism and unrelated
     *         tests reading the leftover values.
     */
    function test_envDependentChainResolution() public {
        // -- Tier 2: PLUME registers with the env-supplied URL.
        vm.setEnv("PLUME_RPC_URL", "https://stub.plume.example");
        harness.callSetUpNonStandardChains();
        StdChains.Chain memory plume = harness.readChain("plume");
        assertEq(plume.chainId, 98866);
        assertEq(plume.name,    "Plume");
        assertEq(plume.rpcUrl,  "https://stub.plume.example");

        // -- Tier 2: MONAD registers with the env-supplied URL.
        vm.setEnv("MONAD_RPC_URL", "https://stub.monad.example");
        harness.callSetUpNonStandardChains();
        StdChains.Chain memory monad = harness.readChain("monad");
        assertEq(monad.chainId, 143);
        assertEq(monad.name,    "Monad");
        assertEq(monad.rpcUrl,  "https://stub.monad.example");

        // -- Tier 2: PLASMA registers with the env-supplied URL.
        vm.setEnv("PLASMA_RPC_URL", "https://stub.plasma.example");
        harness.callSetUpNonStandardChains();
        StdChains.Chain memory plasma = harness.readChain("plasma");
        assertEq(plasma.chainId, 9745);
        assertEq(plasma.name,    "Plasma");
        assertEq(plasma.rpcUrl,  "https://stub.plasma.example");

        // -- resolveChainFromInputs picks up a tier-2 chain together with its env-supplied URL.
        StdChains.Chain memory resolvedMonad =
            harness.callResolveChainFromInputs("monad", "", 0);
        assertEq(resolvedMonad.chainAlias, "monad");
        assertEq(resolvedMonad.chainId,    143);
        assertEq(resolvedMonad.rpcUrl,     "https://stub.monad.example");

        // -- Tier-2 alias with no resolvable RPC URL: forge-std surfaces "invalid rpc url: <alias>".
        //    `setUpNonStandardChains` is invoked inside callResolveChainFromInputs and re-registers
        //    plume with whatever PLUME_RPC_URL holds at this moment, so wipe it first.
        vm.setEnv("PLUME_RPC_URL", "");
        vm.expectRevert("invalid rpc url: plume");
        harness.callResolveChainFromInputs("plume", "", 0);
    }

}
