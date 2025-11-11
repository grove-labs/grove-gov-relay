// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { CCTPv2Forwarder } from 'lib/xchain-helpers/src/forwarders/CCTPv2Forwarder.sol';

import { CrosschainPayload, IPayload } from './CrosschainPayload.sol';

contract AvalancheCCTPv2CrosschainPayload is CrosschainPayload {

    constructor(IPayload _targetPayload, address _bridgeReceiver) CrosschainPayload(_targetPayload, _bridgeReceiver) {}

    function execute() external override {
        CCTPv2Forwarder.sendMessage(
            CCTPv2Forwarder.MESSAGE_TRANSMITTER_CIRCLE_ETHEREUM,
            CCTPv2Forwarder.DOMAIN_ID_CIRCLE_AVALANCHE,
            bridgeReceiver,
            encodeCrosschainExecutionMessage()
        );
    }

}
