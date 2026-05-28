// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { Script }    from "forge-std/Script.sol";
import { StdChains } from "forge-std/StdChains.sol";

import { Verify } from "../deploy/Verify.sol";

/**
 * @title  BaseDeployScript
 * @notice Shared chain-selection logic for every Deploy<X> script.
 *
 * @dev Three tiers of chain support are provided, in order of preference:
 *
 *      1. Forge built-in chain registry (e.g. mainnet, optimism, base, arbitrum_one,
 *         gnosis_chain, avalanche, unichain). The operator only needs to set:
 *           CHAIN=<alias>
 *           <ALIAS>_RPC_URL=<endpoint>      (forge convention; e.g. OPTIMISM_RPC_URL)
 *
 *      2. Pre-registered non-standard chains (Plume, Monad, Plasma, ...). Each is
 *         registered once in `setUpNonStandardChains()`. Adding a new non-standard chain
 *         is a one-line edit there - no per-receiver script changes are required.
 *           CHAIN=plume
 *           PLUME_RPC_URL=<endpoint>
 *
 *      3. Brand-new / one-off chain provided entirely at runtime - no Solidity edits
 *         required. The operator additionally sets:
 *           CHAIN=<arbitrary-alias>
 *           CHAIN_RPC_URL=<endpoint>
 *           CHAIN_ID=<chain-id>
 *         The chain is registered on the fly via `setChain` and used as if it were
 *         tier 1 or tier 2.
 *
 *      After resolution, `vm.createSelectFork` ties the in-memory fork to the chosen
 *      chain and `Verify.verifyChainId` asserts `block.chainid` matches - so a wrong
 *      RPC / wrong CHAIN combination fails fast before any broadcast.
 */
abstract contract BaseDeployScript is Script {

    /**
     * @notice Adds chain entries that forge-std doesn't ship with by default.
     *         Add a single line per new known chain. Receivers do not need to be
     *         updated when this list grows.
     */
    function setUpNonStandardChains() internal {
        setChain("plume",  StdChains.ChainData({
            name    : "Plume",
            chainId : 98866,
            rpcUrl  : vm.envOr("PLUME_RPC_URL", string(""))
        }));
        setChain("monad",  StdChains.ChainData({
            name    : "Monad",
            chainId : 143,
            rpcUrl  : vm.envOr("MONAD_RPC_URL", string(""))
        }));
        setChain("plasma", StdChains.ChainData({
            name    : "Plasma",
            chainId : 9745,
            rpcUrl  : vm.envOr("PLASMA_RPC_URL", string(""))
        }));
    }

    /**
     * @notice Pure-logic core of chain resolution. Takes env-var values as plain arguments
     *         so it can be unit-tested with arbitrary combinations.
     *
     * @param  chainName Operator-supplied CHAIN alias (must be non-empty).
     * @param  adHocRpc  Optional CHAIN_RPC_URL for tier-3 ad-hoc registration ("" if unused).
     * @param  adHocId   Optional CHAIN_ID for tier-3 ad-hoc registration (0 if unused).
     * @return c         Fully-resolved chain ready to be forked against.
     *
     * @dev Validates: CHAIN is set; CHAIN_RPC_URL and CHAIN_ID are both set or neither;
     *      and the resolved chain has a non-empty rpcUrl after tier 1/2/3 resolution.
     */
    function resolveChainFromInputs(
        string memory chainName,
        string memory adHocRpc,
        uint256       adHocId
    ) internal returns (StdChains.Chain memory c) {
        require(
            bytes(chainName).length > 0,
            "BaseDeployScript/missing-CHAIN-env-var: set CHAIN=<alias> (see Makefile header for tier 1/2/3 examples)"
        );

        // Tier 2: known non-standard chains.
        setUpNonStandardChains();

        // Tier 3: ad-hoc chain provided entirely at runtime. Overrides any registration
        // made by tier 1 or tier 2 if both `CHAIN_RPC_URL` and `CHAIN_ID` are set.
        bool rpcSet = bytes(adHocRpc).length > 0;
        bool idSet  = adHocId != 0;
        require(
            rpcSet == idSet,
            "BaseDeployScript/partial-ad-hoc-chain: set both CHAIN_RPC_URL and CHAIN_ID, or neither"
        );
        if (rpcSet) {
            setChain(chainName, StdChains.ChainData({
                name    : chainName,
                chainId : adHocId,
                rpcUrl  : adHocRpc
            }));
        }

        // forge-std's `getChain` itself reverts with "invalid rpc url: <alias>" when no
        // resolvable RPC URL exists for the chain (no entry in foundry.toml [rpc_endpoints],
        // no `<ALIAS>_RPC_URL` env var, no built-in default). That check is enough; we don't
        // duplicate it here.
        c = getChain(chainName);
    }

    /**
     * @notice Reads the `CHAIN`, `CHAIN_RPC_URL`, `CHAIN_ID` env vars and feeds them to
     *         `resolveChainFromInputs`. Trivial wrapper, kept so the env-var IO is the only
     *         non-unit-testable seam in the chain-selection flow.
     */
    function resolveChain() internal returns (StdChains.Chain memory) {
        return resolveChainFromInputs(
            vm.envOr("CHAIN",         string("")),
            vm.envOr("CHAIN_RPC_URL", string("")),
            vm.envOr("CHAIN_ID",      uint256(0))
        );
    }

    /**
     * @notice Resolves the destination chain (`resolveChain`), forks against it, and asserts
     *         `block.chainid` matches the resolved chain.
     *
     * @dev    The fork + chainId-assert tail of this function is intentionally not unit-tested
     *         because it requires a real RPC; that piece is excluded from the coverage gate.
     *         All testable resolution logic lives in `resolveChainFromInputs`.
     */
    function selectChain() internal returns (string memory chainName, uint256 chainId) {
        StdChains.Chain memory c = resolveChain();
        chainName = c.chainAlias;
        chainId   = c.chainId;

        vm.createSelectFork(c.rpcUrl);

        // Belt-and-braces: makes a wrong-chain deploy impossible even if a misconfigured
        // alias somehow points at the wrong RPC.
        Verify.verifyChainId(chainId);
    }

}
