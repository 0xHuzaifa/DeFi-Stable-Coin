// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {HuzaifaStableCoin} from "../src/HuzaifaStableCoin.sol";
import {HSCEngine} from "../src/HSCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployHsc is Script {

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;
    
    function run() external returns(HuzaifaStableCoin, HSCEngine, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mock

        (address wethPriceFeedAddress, address wbtcPriceFeedAddress, address weth, address wbtc, uint256 deployerKey)
            = helperConfig.activeNetworkConfig();

        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethPriceFeedAddress, wbtcPriceFeedAddress];

        vm.startBroadcast(deployerKey);

        HuzaifaStableCoin hsc = new HuzaifaStableCoin();
        HSCEngine engine = new HSCEngine(
            tokenAddresses, 
            priceFeedAddresses, 
            address(hsc)
        );
        hsc.transferOwnership(address(engine));

        vm.stopBroadcast();

        return (hsc, engine, helperConfig);
    }
}