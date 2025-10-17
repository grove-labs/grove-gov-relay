// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { CCTPForwarder } from 'lib/xchain-helpers/src/forwarders/CCTPForwarder.sol';

import { CrosschainPayload, IPayload } from './CrosschainPayload.sol';

contract AvalancheCCTPCrosschainPayload is CrosschainPayload {

    constructor(IPayload _targetPayload, address _bridgeReceiver) CrosschainPayload(_targetPayload, _bridgeReceiver) {}

    function execute() external override {
        CCTPForwarder.sendMessage(
            CCTPForwarder.MESSAGE_TRANSMITTER_CIRCLE_ETHEREUM,
            CCTPForwarder.DOMAIN_ID_CIRCLE_AVALANCHE,
            bridgeReceiver,
            encodeCrosschainExecutionMessage()
        );
    }

}
