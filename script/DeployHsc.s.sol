// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {HuzaifaStableCoin} from "../src/HuzaifaStableCoin.sol";
import {HSCEngine} from "../src/HSCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployHSC is Script {

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;
    
    function run() external returns(HuzaifaStableCoin, HSCEngine, HelperConfig) {
        HelperConfig config = new HelperConfig(); // This comes with our mock

        (address wethPriceFeed, address wbtcPriceFeed, address weth, address wbtc, 
        uint256 deployerKey) = config.activeNetworkConfig();

        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethPriceFeed, wbtcPriceFeed];

        vm.startBroadcast(deployerKey);

        HuzaifaStableCoin hsc = new HuzaifaStableCoin();
        HSCEngine engine = new HSCEngine(
            tokenAddresses, 
            priceFeedAddresses, 
            address(hsc)
        );
        hsc.transferOwnership(address(engine));

        vm.stopBroadcast();

        return (hsc, engine, config);
    }
}