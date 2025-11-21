// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import './CrosschainTestBase.sol';

import { CCTPv2BridgeTesting } from 'lib/xchain-helpers/src/testing/bridges/CCTPv2BridgeTesting.sol';
import { CCTPv2Forwarder }     from 'lib/xchain-helpers/src/forwarders/CCTPv2Forwarder.sol';
import { CCTPv2Receiver }      from 'lib/xchain-helpers/src/receivers/CCTPv2Receiver.sol';

import { AvalancheCCTPv2CrosschainPayload } from './payloads/AvalancheCCTPv2CrosschainPayload.sol';

contract AvalancheCCTPv2CrosschainTest is CrosschainTestBase {

    using DomainHelpers       for *;
    using CCTPv2BridgeTesting for *;

    function deployCrosschainPayload(IPayload targetPayload, address bridgeReceiver)
        internal override returns (IPayload)
    {
        return IPayload(new AvalancheCCTPv2CrosschainPayload(targetPayload, bridgeReceiver));
    }

    function setupDomain() internal override {
        remote = getChain('avalanche').createFork();
        bridge = CCTPv2BridgeTesting.createCircleBridge(
            mainnet,
            remote
        );

        remote.selectFork();
        bridgeReceiver = address(new CCTPv2Receiver(
            CCTPv2BridgeTesting.getCircleMessengerFromChainAlias(bridge.destination.chain.chainAlias),
            CCTPv2Forwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
            bytes32(uint256(uint160(defaultL2BridgeExecutorArgs.ethereumGovernanceExecutor))),
            vm.computeCreateAddress(address(this), 3)
        ));
    }

    function relayMessagesAcrossBridge() internal override {
        bridge.relayMessagesToDestination(true);
    }

}
