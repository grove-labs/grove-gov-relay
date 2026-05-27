# =============================================================================
# Deployment recipes for Executor + receiver pairs across many chains.
# =============================================================================
#
# Operator workflow:
#   1. Pick a per-receiver script (Arbitrum / Optimism / AMB / CCTPv2 / LZ).
#   2. Decide whether you want a "full" (Executor + Receiver) or "receiver-only"
#      deploy (re-using an already-deployed Executor on the destination chain).
#   3. Tell the script which chain to target. Three tiers are supported - you
#      pick whichever tier matches the chain.
#
# -----------------------------------------------------------------------------
# Tier 1 - Standard chains (forge built-in registry)
# -----------------------------------------------------------------------------
#   Forge knows these aliases out of the box: mainnet, optimism, base,
#   arbitrum_one, gnosis_chain, avalanche, unichain, world_chain, ...
#
#   Required env vars:
#     CHAIN              forge alias (e.g. arbitrum_one)
#     <ALIAS>_RPC_URL    matching RPC endpoint (e.g. ARBITRUM_ONE_RPC_URL=...)
#
#   Example:
#     CHAIN=arbitrum_one ARBITRUM_ONE_RPC_URL=https://... \
#       make deploy-arbitrum-full
#
#   Pre-wired convenience targets (under "Pre-wired chain shortcuts" below)
#   set CHAIN automatically for the most common destinations.
#
# -----------------------------------------------------------------------------
# Tier 2 - Pre-registered non-standard chains
# -----------------------------------------------------------------------------
#   Chains that forge does not know natively but are registered in
#   `script/BaseDeployScript.sol::setUpNonStandardChains()`.
#   Currently: plume, monad, plasma. Adding a new known chain is a one-line
#   edit in that function - per-receiver scripts do not need to change.
#
#   Required env vars:
#     CHAIN              alias matching the registered name (e.g. plume)
#     <ALIAS>_RPC_URL    matching RPC endpoint (e.g. PLUME_RPC_URL=...)
#
#   Example:
#     CHAIN=plume PLUME_RPC_URL=https://... \
#       make deploy-arbitrum-full
#
# -----------------------------------------------------------------------------
# Tier 3 - Brand-new / one-off chain (no Solidity edits required)
# -----------------------------------------------------------------------------
#   Use this for any chain not yet known to forge or registered in
#   setUpNonStandardChains. The script registers the chain on the fly via
#   `setChain` and validates the runtime chainId against the value you pass.
#
#   Required env vars:
#     CHAIN              an alias of your choosing (used as the config slug)
#     CHAIN_RPC_URL      RPC endpoint of the new chain
#     CHAIN_ID           numeric chain id of the new chain
#
#   Example:
#     CHAIN=newchain \
#     CHAIN_RPC_URL=https://rpc.newchain.io \
#     CHAIN_ID=99999 \
#       make deploy-arbitrum-full
#
#   For etherscan-style verification on a brand-new chain, also set:
#     FORGE_FLAGS="--verifier blockscout --verifier-url https://newchain-explorer/api"
#   or pass an Etherscan v2-compatible key via `ETHERSCAN_API_KEY`. If the chain
#   has no explorer at all, leave `--verify` out of FORGE_FLAGS (see below).
#
# -----------------------------------------------------------------------------
# Config files
# -----------------------------------------------------------------------------
# Each script reads `script/config/<receiver>.<chain>.json` by default
# (e.g. `arbitrum.plume.json`, `lz.avalanche.json`). Override the slug
# explicitly with `CONFIG=<slug>` (useful for staging / per-environment files
# such as `arbitrum.plume.staging`).
#
# -----------------------------------------------------------------------------
# Etherscan verification
# -----------------------------------------------------------------------------
# `--verify` is always passed; forge uses the `[etherscan]` block in
# foundry.toml plus your `ETHERSCAN_API_KEY` (Etherscan v2 unified key) to
# pick the right endpoint based on the runtime chainId. For chains without
# Etherscan-family support, override via `FORGE_FLAGS=--verifier blockscout
# --verifier-url https://...` or skip verification by overriding `VERIFY=`.
#
# -----------------------------------------------------------------------------
# Authentication
# -----------------------------------------------------------------------------
# Auth flags are not hard-coded so each developer can pick their signer:
#   make deploy-amb-full FORGE_FLAGS="--account MY_KEYSTORE_ACCOUNT"
#   make deploy-arbitrum-full FORGE_FLAGS="--ledger --sender 0xabc..."
#   make deploy-cctp-v2-full FORGE_FLAGS="--private-key $$DEPLOYER_PK"
# Forge also picks up auth from env vars (ETH_FROM, ETH_KEYSTORE_ACCOUNT,
# ETH_PRIVATE_KEY, ...) on its own, so FORGE_FLAGS may be empty.
# =============================================================================

# Forge reads the env vars `CHAIN`, `CHAIN_RPC_URL`, `CHAIN_ID`, `CONFIG` (and
# `<alias>_RPC_URL`) via `vm.envOr` / `vm.envString` in the scripts. Exporting
# them here lets target-scoped variable assignments below propagate into the
# shell environment of the underlying deploy recipes.
export CHAIN
export CHAIN_RPC_URL
export CHAIN_ID
export CONFIG

FORGE_FLAGS ?=
VERIFY      ?= --verify

.PHONY: \
    deploy-arbitrum-full deploy-arbitrum-receiver \
    deploy-optimism-full deploy-optimism-receiver \
    deploy-cctp-v2-full  deploy-cctp-v2-receiver \
    deploy-lz-full       deploy-lz-receiver \
    deploy-amb-full      deploy-amb-receiver \
    deploy-arbitrum-full-arbitrum-one     deploy-arbitrum-receiver-arbitrum-one \
    deploy-arbitrum-full-plume            deploy-arbitrum-receiver-plume \
    deploy-optimism-full-optimism         deploy-optimism-receiver-optimism \
    deploy-optimism-full-base             deploy-optimism-receiver-base \
    deploy-optimism-full-unichain         deploy-optimism-receiver-unichain \
    deploy-optimism-full-monad            deploy-optimism-receiver-monad \
    deploy-cctp-v2-full-avalanche         deploy-cctp-v2-receiver-avalanche \
    deploy-lz-full-plasma                 deploy-lz-receiver-plasma \
    deploy-lz-full-avalanche              deploy-lz-receiver-avalanche \
    deploy-amb-full-gnosis                deploy-amb-receiver-gnosis

# -----------------------------------------------------------------------------
# Generic deployment targets.
# -----------------------------------------------------------------------------
# `CHAIN` and the matching `<ALIAS>_RPC_URL` (or `CHAIN_RPC_URL`+`CHAIN_ID` for
# tier 3) must be set in the environment. The script picks the JSON config
# from `script/config/<receiver>.<CHAIN>.json` unless `CONFIG` overrides it.
deploy-arbitrum-full     :; forge script script/DeployArbitrum.s.sol:DeployArbitrumFull         --broadcast $(VERIFY) $(FORGE_FLAGS)
deploy-arbitrum-receiver :; forge script script/DeployArbitrum.s.sol:DeployArbitrumReceiverOnly --broadcast $(VERIFY) $(FORGE_FLAGS)

deploy-optimism-full     :; forge script script/DeployOptimism.s.sol:DeployOptimismFull         --broadcast $(VERIFY) $(FORGE_FLAGS)
deploy-optimism-receiver :; forge script script/DeployOptimism.s.sol:DeployOptimismReceiverOnly --broadcast $(VERIFY) $(FORGE_FLAGS)

deploy-cctp-v2-full      :; forge script script/DeployCCTPv2.s.sol:DeployCCTPv2Full             --broadcast $(VERIFY) $(FORGE_FLAGS)
deploy-cctp-v2-receiver  :; forge script script/DeployCCTPv2.s.sol:DeployCCTPv2ReceiverOnly     --broadcast $(VERIFY) $(FORGE_FLAGS)

deploy-lz-full           :; forge script script/DeployLZ.s.sol:DeployLZFull                     --broadcast $(VERIFY) $(FORGE_FLAGS)
deploy-lz-receiver       :; forge script script/DeployLZ.s.sol:DeployLZReceiverOnly             --broadcast $(VERIFY) $(FORGE_FLAGS)

deploy-amb-full          :; forge script script/DeployAMB.s.sol:DeployAMBFull                   --broadcast $(VERIFY) $(FORGE_FLAGS)
deploy-amb-receiver      :; forge script script/DeployAMB.s.sol:DeployAMBReceiverOnly           --broadcast $(VERIFY) $(FORGE_FLAGS)

# -----------------------------------------------------------------------------
# Pre-wired chain shortcuts.
# -----------------------------------------------------------------------------
# Each pre-wired target sets `CHAIN` to the relevant forge alias; the alias's
# RPC URL is read from the conventional `<ALIAS>_RPC_URL` env var (e.g.
# `PLUME_RPC_URL`, `ARBITRUM_ONE_RPC_URL`). The default `CONFIG` slug derived
# by the script is `<receiver>.<CHAIN>` - operators only override `CONFIG` for
# bespoke per-environment files.
#
# To add another pre-wired chain: copy a block below and change `CHAIN`.
# To target a chain that is NOT pre-wired here, just set `CHAIN` (and the
# tier 3 env vars if needed) directly when invoking the generic target above.

# Arbitrum-style
deploy-arbitrum-full-arbitrum-one:     CHAIN := arbitrum_one
deploy-arbitrum-full-arbitrum-one:     deploy-arbitrum-full
deploy-arbitrum-receiver-arbitrum-one: CHAIN := arbitrum_one
deploy-arbitrum-receiver-arbitrum-one: deploy-arbitrum-receiver

deploy-arbitrum-full-plume:            CHAIN := plume
deploy-arbitrum-full-plume:            deploy-arbitrum-full
deploy-arbitrum-receiver-plume:        CHAIN := plume
deploy-arbitrum-receiver-plume:        deploy-arbitrum-receiver

# Optimism-style
deploy-optimism-full-optimism:         CHAIN := optimism
deploy-optimism-full-optimism:         deploy-optimism-full
deploy-optimism-receiver-optimism:     CHAIN := optimism
deploy-optimism-receiver-optimism:     deploy-optimism-receiver

deploy-optimism-full-base:             CHAIN := base
deploy-optimism-full-base:             deploy-optimism-full
deploy-optimism-receiver-base:         CHAIN := base
deploy-optimism-receiver-base:         deploy-optimism-receiver

deploy-optimism-full-unichain:         CHAIN := unichain
deploy-optimism-full-unichain:         deploy-optimism-full
deploy-optimism-receiver-unichain:     CHAIN := unichain
deploy-optimism-receiver-unichain:     deploy-optimism-receiver

deploy-optimism-full-monad:            CHAIN := monad
deploy-optimism-full-monad:            deploy-optimism-full
deploy-optimism-receiver-monad:        CHAIN := monad
deploy-optimism-receiver-monad:        deploy-optimism-receiver

# CCTP v2
deploy-cctp-v2-full-avalanche:         CHAIN := avalanche
deploy-cctp-v2-full-avalanche:         deploy-cctp-v2-full
deploy-cctp-v2-receiver-avalanche:     CHAIN := avalanche
deploy-cctp-v2-receiver-avalanche:     deploy-cctp-v2-receiver

# LayerZero
deploy-lz-full-plasma:                 CHAIN := plasma
deploy-lz-full-plasma:                 deploy-lz-full
deploy-lz-receiver-plasma:             CHAIN := plasma
deploy-lz-receiver-plasma:             deploy-lz-receiver

deploy-lz-full-avalanche:              CHAIN := avalanche
deploy-lz-full-avalanche:              deploy-lz-full
deploy-lz-receiver-avalanche:          CHAIN := avalanche
deploy-lz-receiver-avalanche:          deploy-lz-receiver

# AMB
deploy-amb-full-gnosis:                CHAIN := gnosis_chain
deploy-amb-full-gnosis:                deploy-amb-full
deploy-amb-receiver-gnosis:            CHAIN := gnosis_chain
deploy-amb-receiver-gnosis:            deploy-amb-receiver
