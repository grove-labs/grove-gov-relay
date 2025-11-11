// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";

import { Ethereum } from "lib/grove-address-registry/src/Ethereum.sol";

import { CCTPForwarder } from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";
import { LZForwarder }   from "lib/xchain-helpers/src/forwarders/LZForwarder.sol";

import { Script } from 'forge-std/Script.sol';

import { Deploy } from "../deploy/Deploy.sol";

import { Verify } from "../deploy/Verify.sol";

contract DeployArbitrumOneExecutor is Script {

    function run() public {
        vm.createSelectFork(getChain("arbitrum_one").rpcUrl);

        Verify.verifyChainId(42161);

        vm.startBroadcast();

        address executor = Deploy.deployExecutor(0, 7 days);
        address receiver = Deploy.deployArbitrumReceiver(Ethereum.GROVE_PROXY, executor);

        console.log("executor deployed at:", executor);
        console.log("receiver deployed at:", receiver);

        Deploy.setUpExecutorPermissions(executor, receiver, msg.sender);

        vm.stopBroadcast();

        Verify.verifyArbitrumDeployment(
            Verify.Deployment({
                executor: executor,
                receiver: receiver,
                deployer: msg.sender
            }),
            Verify.ExecutorParams({
                delay:       0,
                gracePeriod: 7 days
            })
        );

    }

}

contract DeployBaseExecutor is Script {

    function run() public {
        vm.createSelectFork(getChain("base").rpcUrl);

        Verify.verifyChainId(8453);

        vm.startBroadcast();

        address executor = Deploy.deployExecutor(0, 7 days);
        address receiver = Deploy.deployOptimismReceiver(Ethereum.GROVE_PROXY, executor);

        console.log("executor deployed at:", executor);
        console.log("receiver deployed at:", receiver);

        Deploy.setUpExecutorPermissions(executor, receiver, msg.sender);

        vm.stopBroadcast();

        Verify.verifyOptimismDeployment(
            Verify.Deployment({
                executor: executor,
                receiver: receiver,
                deployer: msg.sender
            }),
            Verify.ExecutorParams({
                delay:       0,
                gracePeriod: 7 days
            })
        );
    }

}

contract DeployOptimismExecutor is Script {

    function run() public {
        vm.createSelectFork(getChain("optimism").rpcUrl);

        Verify.verifyChainId(10);

        vm.startBroadcast();

        address executor = Deploy.deployExecutor(0, 7 days);
        address receiver = Deploy.deployOptimismReceiver(Ethereum.GROVE_PROXY, executor);

        console.log("executor deployed at:", executor);
        console.log("receiver deployed at:", receiver);

        Deploy.setUpExecutorPermissions(executor, receiver, msg.sender);

        vm.stopBroadcast();

        Verify.verifyOptimismDeployment(
            Verify.Deployment({
                executor: executor,
                receiver: receiver,
                deployer: msg.sender
            }),
            Verify.ExecutorParams({
                delay:       0,
                gracePeriod: 7 days
            })
        );
    }

}

contract DeployUnichainExecutor is Script {

    function run() public {
        vm.createSelectFork(vm.envString("UNICHAIN_RPC_URL"));

        Verify.verifyChainId(130);

        vm.startBroadcast();

        address executor = Deploy.deployExecutor(0, 7 days);
        address receiver = Deploy.deployOptimismReceiver(Ethereum.GROVE_PROXY, executor);

        console.log("executor deployed at:", executor);
        console.log("receiver deployed at:", receiver);

        Deploy.setUpExecutorPermissions(executor, receiver, msg.sender);

        vm.stopBroadcast();

        Verify.verifyOptimismDeployment(
            Verify.Deployment({
                executor: executor,
                receiver: receiver,
                deployer: msg.sender
            }),
            Verify.ExecutorParams({
                delay:       0,
                gracePeriod: 7 days
            })
        );
    }

}

contract DeployAvalancheExecutor is Script {

    function run() public {
        vm.createSelectFork(getChain("avalanche").rpcUrl);

        Verify.verifyChainId(43114);

        vm.startBroadcast();

        address executor = Deploy.deployExecutor(0, 7 days);
        address receiver = Deploy.deployCCTPReceiver(
            CCTPForwarder.MESSAGE_TRANSMITTER_CIRCLE_AVALANCHE,
            CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
            bytes32(uint256(uint160(Ethereum.GROVE_PROXY))),
            executor
        );

        console.log("executor deployed at:", executor);
        console.log("receiver deployed at:", receiver);

        Deploy.setUpExecutorPermissions(executor, receiver, msg.sender);

        vm.stopBroadcast();

        Verify.verifyCctpDeployment(
            Verify.Deployment({
                executor: executor,
                receiver: receiver,
                deployer: msg.sender
            }),
            Verify.ExecutorParams({
                delay:       0,
                gracePeriod: 7 days
            }),
            CCTPForwarder.MESSAGE_TRANSMITTER_CIRCLE_AVALANCHE
        );
    }

}

contract DeployPlumeExecutor is Script {

    function run() public {
        vm.createSelectFork(vm.envString("PLUME_RPC_URL"));

        Verify.verifyChainId(98866);

        vm.startBroadcast();

        address executor = Deploy.deployExecutor(0, 7 days);
        address receiver = Deploy.deployArbitrumReceiver(Ethereum.GROVE_PROXY, executor);

        console.log("executor deployed at:", executor);
        console.log("receiver deployed at:", receiver);

        Deploy.setUpExecutorPermissions(executor, receiver, msg.sender);

        vm.stopBroadcast();

        Verify.verifyArbitrumDeployment(
            Verify.Deployment({
                executor: executor,
                receiver: receiver,
                deployer: msg.sender
            }),
            Verify.ExecutorParams({
                delay:       0,
                gracePeriod: 7 days
            })
        );
    }

}

contract DeployPlasmaExecutor is Script {

    function run() public {
        vm.createSelectFork(vm.envString("PLASMA_RPC_URL"));

        Verify.verifyChainId(9745);

        vm.startBroadcast();

        address executor = Deploy.deployExecutor(0, 7 days);
        address receiver = Deploy.deployLZReceiver({
            destinationEndpoint : LZForwarder.ENDPOINT_PLASMA,
            srcEid              : LZForwarder.ENDPOINT_ID_ETHEREUM,
            sourceAuthority     : Ethereum.GROVE_PROXY,
            executor            : executor,
            delegate            : address(1),
            owner               : address(1)
        });

        console.log("executor deployed at:", executor);
        console.log("receiver deployed at:", receiver);

        Deploy.setUpExecutorPermissions(executor, receiver, msg.sender);

        vm.stopBroadcast();
    }

}


contract DeployMonadExecutor is Script {

    function run() public {
        vm.createSelectFork(vm.envString("MONAD_RPC_URL"));

        Verify.verifyChainId(143);

        vm.startBroadcast();

        address executor = Deploy.deployExecutor(0, 7 days);
        address receiver = Deploy.deployLZReceiver({
            destinationEndpoint : LZForwarder.ENDPOINT_MONAD,
            srcEid              : LZForwarder.ENDPOINT_ID_ETHEREUM,
            sourceAuthority     : Ethereum.GROVE_PROXY,
            executor            : executor,
            delegate            : address(1),
            owner               : address(1)
        });

        console.log("executor deployed at:", executor);
        console.log("receiver deployed at:", receiver);

        Deploy.setUpExecutorPermissions(executor, receiver, msg.sender);

        vm.stopBroadcast();
    }

}


