// 1. Deploy Mocks when we are on a local anvil chain
// 2. Keep track of contract addresses across different chains
// Sepolia ETH/USD feed address: 0x694AA1769357215DE4FAC081bf1f309aDC325306
// Mainnet ETH/USD feed address: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {FundMe} from "src/FundMe.sol";
import {DeployFundMe} from "script/DeployFundMe.s.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";

contract HelperConfig is Script {
    // if we are on a local anvil chain, we deploy MOCKS
    // otherwise, grab the existing address from the live network

    NetworkConfig public activeNetworkConfig; //setting a state to hold the network config for the current chain depending on the chain id

    //we take this precaution to avoid magic numbers way down below
    //as it makes it lot easier to maintain the code
    uint8 public constant DECIMALS = 8;
    int256 public constant INITIAL_PRICE = 2000e8;

    struct NetworkConfig {
        address priceFeed; //ETH/USD price feed address
    }

    //chainId: refers to the chain's current id
    //
    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else if (block.chainid == 1) {
            activeNetworkConfig = getMainnetEthConfig();
        } else {
            activeNetworkConfig = getorCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        // needs price feed address
        //but if we need more than just an address, we should consider creating our own type using struct
        NetworkConfig memory sepoliaConfig = NetworkConfig({priceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306});
        return sepoliaConfig;
    }

    function getorCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.priceFeed != address(0)) {
            return activeNetworkConfig; //if we already have the address then the address won't be zero, so we don't need to set it again here, we can just return the previous config
        }
        // needs price feed address

        //1. Deploy Mocks when we are on a local anvil chain
        //2. Return the mock address

        vm.startBroadcast();
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(DECIMALS, INITIAL_PRICE); //click on MockV3Aggregator with ctrl to see the constructor inputs, decimals for eth is 8 and the initialAnswer is 2000e8
        vm.stopBroadcast();

        NetworkConfig memory anvilConfig = NetworkConfig({priceFeed: address(mockPriceFeed)});
        return anvilConfig;
    }

    function getMainnetEthConfig() public pure returns (NetworkConfig memory) {
        // needs price feed address
        //but if we need more than just an address, we should consider creating our own type using struct
        NetworkConfig memory sepoliaConfig = NetworkConfig({priceFeed: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419});
        return sepoliaConfig;
    }
}
