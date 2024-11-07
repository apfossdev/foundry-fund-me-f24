// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {FundMe} from "src/FundMe.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract DeployFundMe is Script {
    function run() external returns (FundMe) {
        // before startBroadcast-> not a real txn
        HelperConfig helperConfig = new HelperConfig();
        address ethUsdPriceFeed = helperConfig.activeNetworkConfig();
        // (address ethUsdPriceFeed, , ,) = helperConfig.activeNetworkConfig(); //if there were more than just one address, we should destructure using commas like this (,address,,,) =

        // after startBroadcast-> real txn
        vm.startBroadcast();
        FundMe fundMe = new FundMe(ethUsdPriceFeed); //we add the price feed address here making the code more modular and refactored it for future change of various chains
        vm.stopBroadcast();
        return fundMe;
    }
}
