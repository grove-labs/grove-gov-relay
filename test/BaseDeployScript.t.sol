// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import { StdChains } from "forge-std/StdChains.sol";

import { BaseDeployScript } from "../script/BaseDeployScript.sol";

/**
 * @notice Concrete instance so we can call `selectChain` / `setUpNonStandardChains`
 *         externally for assertions. Tests don't actually call `vm.createSelectFork`
 *         (we'd need a real RPC for that); instead they exercise the registration
 *         logic directly via `setUpNonStandardChains` and `getChain`.
 */
contract BaseDeployScriptHarness is BaseDeployScript {

    function callSetUpNonStandardChains() external {
        setUpNonStandardChains();
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
        assertEq(c.chainId,                          98866);
        assertEq(c.name,                             "Plume");
        assertEq(c.rpcUrl,                           "https://stub.plume.example");
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
    /*** Tier 3: ad-hoc custom chain via setChain (mirrors what `selectChain` does internally)  ***/
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

}
