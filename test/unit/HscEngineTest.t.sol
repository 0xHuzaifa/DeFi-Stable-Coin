// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {HSCEngine} from "../../src/HSCEngine.sol";
import {HuzaifaStableCoin} from "../../src/HuzaifaStableCoin.sol";
import {DeployHsc} from "../../script/DeployHsc.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract HscEngineTest is Test {

    HuzaifaStableCoin hsc;
    HSCEngine engine;
    HelperConfig helperConfig;

    address ethUsdPriceFeed;
    address weth;

    function setuo() public {
        DeployHsc deployer = new DeployHsc();
        deployer.run();

        (ethUsdPriceFeed,,weth,,) = helperConfig.activeNetworkConfig();
    }


    /////////////////////////
    // Price Test          //
    /////////////////////////

    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 3000e18;
        uint256 actualUsd = engine.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }


}