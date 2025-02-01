// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {BridgeContract} from "../src/BridgeContract.sol";

contract DeployBridge is Script {
    function run() public returns (BridgeContract) {
        vm.startBroadcast();
        BridgeContract bridge = new BridgeContract();
        vm.stopBroadcast();
        return bridge;
    }
}
