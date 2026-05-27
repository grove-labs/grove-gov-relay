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
     * @notice Resolves the destination chain from environment variables, registers it
     *         in forge's chain registry if needed, switches the in-memory fork to it
     *         and asserts `block.chainid` matches the resolved chain.
     *
     * @return chainName Forge-registry alias of the chain (e.g. "optimism", "plume",
     *                   or any operator-chosen alias for tier 3).
     * @return chainId   Numeric chain id of that chain.
     */
    function selectChain() internal returns (string memory chainName, uint256 chainId) {
        chainName = vm.envOr("CHAIN", string(""));
        require(
            bytes(chainName).length > 0,
            "BaseDeployScript/missing-CHAIN-env-var: set CHAIN=<alias> (see Makefile header for tier 1/2/3 examples)"
        );

        // Tier 2: known non-standard chains.
        setUpNonStandardChains();

        // Tier 3: ad-hoc chain provided entirely at runtime. Overrides any registration
        // made by tier 1 or tier 2 if both `CHAIN_RPC_URL` and `CHAIN_ID` are set.
        string memory adHocRpc = vm.envOr("CHAIN_RPC_URL", string(""));
        uint256       adHocId  = vm.envOr("CHAIN_ID",      uint256(0));
        if (bytes(adHocRpc).length > 0 && adHocId != 0) {
            setChain(chainName, StdChains.ChainData({
                name    : chainName,
                chainId : adHocId,
                rpcUrl  : adHocRpc
            }));
        } else {
            require(
                bytes(adHocRpc).length == 0 && adHocId == 0,
                "BaseDeployScript/partial-ad-hoc-chain: set both CHAIN_RPC_URL and CHAIN_ID, or neither"
            );
        }

        StdChains.Chain memory c = getChain(chainName);
        require(
            bytes(c.rpcUrl).length > 0,
            string.concat(
                "BaseDeployScript/missing-rpc-url-for-chain: ",
                chainName,
                " (set the corresponding *_RPC_URL env var, or set CHAIN_RPC_URL+CHAIN_ID for an ad-hoc chain)"
            )
        );

        vm.createSelectFork(c.rpcUrl);
        chainId = c.chainId;

        // Belt-and-braces: makes a wrong-chain deploy impossible even if a misconfigured
        // alias somehow points at the wrong RPC.
        Verify.verifyChainId(chainId);
    }

}
