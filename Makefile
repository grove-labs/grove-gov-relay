deploy-arbitrum-one :; forge script script/Deploy.s.sol:DeployArbitrumOneExecutor --sender ${ETH_FROM} --broadcast --verify
deploy-base         :; forge script script/Deploy.s.sol:DeployBaseExecutor --sender ${ETH_FROM} --broadcast --verify
deploy-optimism     :; forge script script/Deploy.s.sol:DeployOptimismExecutor --sender ${ETH_FROM} --broadcast --verify
deploy-unichain     :; forge script script/Deploy.s.sol:DeployUnichainExecutor --sender ${ETH_FROM} --broadcast --verify
deploy-avalanche    :; forge script script/Deploy.s.sol:DeployAvalancheExecutor --sender ${ETH_FROM} --broadcast --verify
deploy-plume        :; forge script script/Deploy.s.sol:DeployPlumeExecutor --sender ${ETH_FROM} --broadcast --verify
