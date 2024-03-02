// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {HSCEngine} from "../../src/HSCEngine.sol";
import {HuzaifaStableCoin} from "../../src/HuzaifaStableCoin.sol";
import {DeployHSC} from "../../script/DeployHSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract HscEngineTest is Test {

    HuzaifaStableCoin hsc;
    HSCEngine engine;
    HelperConfig config;

    address ethUsdPriceFeed;
    address weth;

    function setUp() public {
        DeployHSC deployer = new DeployHSC();
        (hsc, engine, config) = deployer.run();

        (ethUsdPriceFeed,,weth,,) = config.activeNetworkConfig();
    }


    /////////////////////////  
    // Price Test          //
    /////////////////////////

    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;
        // 15e18 ETH * $2000/ETH = $30,000e18
        uint256 expectedUsd = 30000e18;
        uint256 usdValue = engine.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, usdValue);
    }

}