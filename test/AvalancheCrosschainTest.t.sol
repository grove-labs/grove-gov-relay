// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import './CrosschainTestBase.sol';

import { CCTPBridgeTesting } from 'lib/xchain-helpers/src/testing/bridges/CCTPBridgeTesting.sol';
import { CCTPReceiver }      from 'lib/xchain-helpers/src/receivers/CCTPReceiver.sol';

import { AvalancheCrosschainPayload } from './payloads/AvalancheCrosschainPayload.sol';

contract AvalancheCrosschainTest is CrosschainTestBase {

    using DomainHelpers     for *;
    using CCTPBridgeTesting for *;

    function deployCrosschainPayload(IPayload targetPayload, address bridgeReceiver)
        internal override returns (IPayload)
    {
        return IPayload(new AvalancheCrosschainPayload(targetPayload, bridgeReceiver));
    }

    function setupDomain() internal override {
        remote = getChain('avalanche').createFork();
        bridge = CCTPBridgeTesting.createCircleBridge(
            mainnet,
            remote
        );

        remote.selectFork();
        bridgeReceiver = address(new CCTPReceiver(
            CCTPBridgeTesting.getCircleMessengerFromChainAlias(bridge.destination.chain.chainAlias),
            uint32(0),  // Ethereum Circle domain id
            bytes32(uint256(uint160(defaultL2BridgeExecutorArgs.ethereumGovernanceExecutor))),
            vm.computeCreateAddress(address(this), 2)
        ));
    }

    function relayMessagesAcrossBridge() internal override {
        bridge.relayMessagesToDestination(true);
    }

}
