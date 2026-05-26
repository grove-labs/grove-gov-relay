# Forge reads `RPC_URL` and `CONFIG` from the environment via `vm.envString` in the
# scripts. Exporting them here lets target-scoped variable assignments below propagate
# into the shell environment of the underlying deploy recipes.
export RPC_URL
export CONFIG

# Auth flags are not hard-coded so each developer can pick their own signer mechanism.
# Pass any forge flags through `FORGE_FLAGS`. Both inline forms work:
#
#   make deploy-amb-full-gnosis FORGE_FLAGS="--account MY_KEYSTORE_ACCOUNT"
#   make deploy-arbitrum-full   FORGE_FLAGS="--ledger --sender 0xabc..."
#   make deploy-cctp-v2-full    FORGE_FLAGS="--private-key $$DEPLOYER_PK"
#
# (the `make TARGET VAR=value` syntax overrides the `?=` default; you do not need to
# export FORGE_FLAGS as an env var first). Forge also picks up auth from env vars
# (ETH_FROM, ETH_KEYSTORE_ACCOUNT, ETH_PRIVATE_KEY, etc.) on its own, so you can leave
# FORGE_FLAGS empty if those are already set.
FORGE_FLAGS ?=

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

# Generic deployment targets. Both `RPC_URL` and `CONFIG` env vars must be set.
# `CONFIG` selects script/config/<CONFIG>.json; `RPC_URL` selects the destination chain.
# Examples:
#   RPC_URL=https://... CONFIG=arbitrum.arbitrum-one make deploy-arbitrum-full
#   RPC_URL=https://... CONFIG=arbitrum.plume        make deploy-arbitrum-receiver
# `--rpc-url $(RPC_URL)` is passed explicitly so forge uses the same endpoint for
# simulation, broadcast routing, and gas estimation that the script's `vm.createSelectFork`
# uses for the in-memory fork. The two settings reference the same `RPC_URL` env var.
deploy-arbitrum-full     :; forge script script/DeployArbitrum.s.sol:DeployArbitrumFull         --rpc-url $(RPC_URL) --broadcast --verify $(FORGE_FLAGS)
deploy-arbitrum-receiver :; forge script script/DeployArbitrum.s.sol:DeployArbitrumReceiverOnly --rpc-url $(RPC_URL) --broadcast --verify $(FORGE_FLAGS)

deploy-optimism-full     :; forge script script/DeployOptimism.s.sol:DeployOptimismFull         --rpc-url $(RPC_URL) --broadcast --verify $(FORGE_FLAGS)
deploy-optimism-receiver :; forge script script/DeployOptimism.s.sol:DeployOptimismReceiverOnly --rpc-url $(RPC_URL) --broadcast --verify $(FORGE_FLAGS)

deploy-cctp-v2-full      :; forge script script/DeployCCTPv2.s.sol:DeployCCTPv2Full             --rpc-url $(RPC_URL) --broadcast --verify $(FORGE_FLAGS)
deploy-cctp-v2-receiver  :; forge script script/DeployCCTPv2.s.sol:DeployCCTPv2ReceiverOnly     --rpc-url $(RPC_URL) --broadcast --verify $(FORGE_FLAGS)

deploy-lz-full           :; forge script script/DeployLZ.s.sol:DeployLZFull                     --rpc-url $(RPC_URL) --broadcast --verify $(FORGE_FLAGS)
deploy-lz-receiver       :; forge script script/DeployLZ.s.sol:DeployLZReceiverOnly             --rpc-url $(RPC_URL) --broadcast --verify $(FORGE_FLAGS)

deploy-amb-full          :; forge script script/DeployAMB.s.sol:DeployAMBFull                   --rpc-url $(RPC_URL) --broadcast --verify $(FORGE_FLAGS)
deploy-amb-receiver      :; forge script script/DeployAMB.s.sol:DeployAMBReceiverOnly           --rpc-url $(RPC_URL) --broadcast --verify $(FORGE_FLAGS)

# Pre-wired chain-specific targets.
# ---------------------------------
# Each one binds `RPC_URL` (per-chain env var) and `CONFIG` (slug of
# `script/config/<receiver>.<chain>.json`, which the operator creates from the matching
# `*.example.json`) and then re-uses the corresponding generic target's recipe.

# Arbitrum-style
deploy-arbitrum-full-arbitrum-one:     RPC_URL := $(ARBITRUM_RPC_URL)
deploy-arbitrum-full-arbitrum-one:     CONFIG  := arbitrum.arbitrum-one
deploy-arbitrum-full-arbitrum-one:     deploy-arbitrum-full
deploy-arbitrum-receiver-arbitrum-one: RPC_URL := $(ARBITRUM_RPC_URL)
deploy-arbitrum-receiver-arbitrum-one: CONFIG  := arbitrum.arbitrum-one
deploy-arbitrum-receiver-arbitrum-one: deploy-arbitrum-receiver

deploy-arbitrum-full-plume:            RPC_URL := $(PLUME_RPC_URL)
deploy-arbitrum-full-plume:            CONFIG  := arbitrum.plume
deploy-arbitrum-full-plume:            deploy-arbitrum-full
deploy-arbitrum-receiver-plume:        RPC_URL := $(PLUME_RPC_URL)
deploy-arbitrum-receiver-plume:        CONFIG  := arbitrum.plume
deploy-arbitrum-receiver-plume:        deploy-arbitrum-receiver

# Optimism-style
deploy-optimism-full-optimism:         RPC_URL := $(OPTIMISM_RPC_URL)
deploy-optimism-full-optimism:         CONFIG  := optimism.optimism
deploy-optimism-full-optimism:         deploy-optimism-full
deploy-optimism-receiver-optimism:     RPC_URL := $(OPTIMISM_RPC_URL)
deploy-optimism-receiver-optimism:     CONFIG  := optimism.optimism
deploy-optimism-receiver-optimism:     deploy-optimism-receiver

deploy-optimism-full-base:             RPC_URL := $(BASE_RPC_URL)
deploy-optimism-full-base:             CONFIG  := optimism.base
deploy-optimism-full-base:             deploy-optimism-full
deploy-optimism-receiver-base:         RPC_URL := $(BASE_RPC_URL)
deploy-optimism-receiver-base:         CONFIG  := optimism.base
deploy-optimism-receiver-base:         deploy-optimism-receiver

deploy-optimism-full-unichain:         RPC_URL := $(UNICHAIN_RPC_URL)
deploy-optimism-full-unichain:         CONFIG  := optimism.unichain
deploy-optimism-full-unichain:         deploy-optimism-full
deploy-optimism-receiver-unichain:     RPC_URL := $(UNICHAIN_RPC_URL)
deploy-optimism-receiver-unichain:     CONFIG  := optimism.unichain
deploy-optimism-receiver-unichain:     deploy-optimism-receiver

deploy-optimism-full-monad:            RPC_URL := $(MONAD_RPC_URL)
deploy-optimism-full-monad:            CONFIG  := optimism.monad
deploy-optimism-full-monad:            deploy-optimism-full
deploy-optimism-receiver-monad:        RPC_URL := $(MONAD_RPC_URL)
deploy-optimism-receiver-monad:        CONFIG  := optimism.monad
deploy-optimism-receiver-monad:        deploy-optimism-receiver

# CCTP v2
deploy-cctp-v2-full-avalanche:         RPC_URL := $(AVALANCHE_RPC_URL)
deploy-cctp-v2-full-avalanche:         CONFIG  := cctp-v2.avalanche
deploy-cctp-v2-full-avalanche:         deploy-cctp-v2-full
deploy-cctp-v2-receiver-avalanche:     RPC_URL := $(AVALANCHE_RPC_URL)
deploy-cctp-v2-receiver-avalanche:     CONFIG  := cctp-v2.avalanche
deploy-cctp-v2-receiver-avalanche:     deploy-cctp-v2-receiver

# LayerZero
deploy-lz-full-plasma:                 RPC_URL := $(PLASMA_RPC_URL)
deploy-lz-full-plasma:                 CONFIG  := lz.plasma
deploy-lz-full-plasma:                 deploy-lz-full
deploy-lz-receiver-plasma:             RPC_URL := $(PLASMA_RPC_URL)
deploy-lz-receiver-plasma:             CONFIG  := lz.plasma
deploy-lz-receiver-plasma:             deploy-lz-receiver

deploy-lz-full-avalanche:              RPC_URL := $(AVALANCHE_RPC_URL)
deploy-lz-full-avalanche:              CONFIG  := lz.avalanche
deploy-lz-full-avalanche:              deploy-lz-full
deploy-lz-receiver-avalanche:          RPC_URL := $(AVALANCHE_RPC_URL)
deploy-lz-receiver-avalanche:          CONFIG  := lz.avalanche
deploy-lz-receiver-avalanche:          deploy-lz-receiver

# AMB
deploy-amb-full-gnosis:                RPC_URL := $(GNOSIS_RPC_URL)
deploy-amb-full-gnosis:                CONFIG  := amb.gnosis
deploy-amb-full-gnosis:                deploy-amb-full
deploy-amb-receiver-gnosis:            RPC_URL := $(GNOSIS_RPC_URL)
deploy-amb-receiver-gnosis:            CONFIG  := amb.gnosis
deploy-amb-receiver-gnosis:            deploy-amb-receiver
