// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {HuzaifaStableCoin} from "./HuzaifaStableCoin.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {AggregatorV3Interface} from "../lib/foundry-chainlink-toolkit/src/interfaces/feeds/AggregatorV3Interface.sol";

/*
 * @title HSCEngine
 * @author Huzaifa Ahmed
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 * This is a stablecoin with the properties:
 * - Exogenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC.
 *
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic
 * for minting and redeeming HSC, as well as depositing and withdrawing collateral.
 * @notice This contract is based on the MakerDAO DSS system
 */
contract HSCEngine is ReentrancyGuard {
    
    //////////////////////
    // Errors          ///
    //////////////////////
    
    error HSCEngine__NeedsMoreThanZero();
    error HSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error HSCEngine__NotAllowedToken(address token);
    error HSCEngine__TransferFailed();
    error HSCEngine__BreakHealthFactor(uint256 healthFactorValue);
    error HSCEngine__MintedFailed();

    //////////////////////////////
    // State Variables         ///
    //////////////////////////////  

    HuzaifaStableCoin private immutable i_hsc;

    uint256 private constant ADITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% Over Collateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;

    /// @dev Mapping of token address to price feed address
    mapping (address token => address priceFeed) private s_priceFeeds;
    /// @dev Amount of collateral deposited by user
    mapping (address user => mapping (address token => uint256 amount)) private s_collateralDeposited;
    /// @dev Amount of hsc minted by user
    mapping (address user => uint256 amountHscMinted) private s_HSCMinted;


    /// @dev If we know exactly how many tokens we have, we could make this immutable!
    address[] private s_collateralTokens;


    /////////////////////////
    // Events              //
    /////////////////////////

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(address indexed user, address indexed token, uint256 indexed amount);

    /////////////////////////
    // Modifiers           //
    /////////////////////////

    modifier moreThanZero(uint256 amount) {
        if(amount <= 0) {
            revert HSCEngine__NeedsMoreThanZero(); 
        }
        _;
    }

    modifier isAllowdToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert HSCEngine__NotAllowedToken(token);
        }
        _;
    }

    ///////////////////////////
    // Constructor          ///
    ///////////////////////////

    constructor(
        address[] memory tokenAddresses, 
        address[] memory priceFeedAddresses, 
        address hscAddress) {
            if (tokenAddresses.length != priceFeedAddresses.length) {
                revert HSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength(); 
            }
            // USD price feed
            for(uint256 i=0; i < tokenAddresses.length; i++) {
                s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
                s_collateralTokens.push(tokenAddresses[i]);
            }
            i_hsc = HuzaifaStableCoin(hscAddress);
    }

    /////////////////////////////
    // External Functions     ///
    /////////////////////////////

    /*
    * @param tokenCollateralAddress The address of the token to deposit as collateral
    * @param amountCollateral The amount of collateral to deposit
    * @param amountHscToMint The amount of Huzaifa Stable Coin to mint
    * @notice This function will deposit your collateral and mint HSC in one transaction
    */
    function depositCollateralAndMintHsc(
        address tokenCollateralAddress, 
        address amountCollateral, 
        uint256 amountHscToMint) external {
            depostiCollateral(tokenCollateralAddress, amountCollateral);
            mintHsc(amountHscToMint);
    }

    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're depositing
     * @param amountCollateral: The amount of collateral you're depositing
     */
    function depostiCollateral(
        address tokenCollateralAddress, 
        uint256 collateralAmount) 
        public 
        moreThanZero(collateralAmount) 
        isAllowdToken(tokenCollateralAddress) 
        nonReentrant {
            s_collateralDeposited[msg.sender][tokenCollateralAddress] += collateralAmount;
            emit CollateralDeposited(msg.sender, tokenCollateralAddress, collateralAmount);

            bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), collateralAmount);
            if (!success) {
                revert HSCEngine__TransferFailed();
            }
    } 

    function redeemCollateralForHsc(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountToBurn) 
    external moreThanZero(amountCollateral) {
        burnHsc(amountToBurn);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
        // redeemCollateral already checks health factor
    }

    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're redeeming
     * @param amountCollateral: The amount of collateral you're redeeming
     * @notice This function will redeem your collateral.
     * @notice If you have HSC minted, you will not be able to redeem until you burn your HSC
     */
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral) 
    public moreThanZero(amountCollateral) nonReentrant isAllowdToken(tokenCollateralAddress){
        s_collateralDeposited[msg.sender][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(msg.sender, tokenCollateralAddress, amountCollateral);

        bool success = IERC20(tokenCollateralAddress).transfer(msg.sender, amountCollateral);
        if (!success) {
            revert HSCEngine__TransferFailed();
        }

        _revertIfHealthFactorIsBroken(msg.sender);
    }
    
    /*
    * @notice follow CEI
    * @param amountHscToMinted The amount of Huzaifa stable coin to minted
    * @notice they must have more collateral value than the minimum threeshold. 
    */
    function mintHsc(uint256 amountHscToMinted) public moreThanZero(amountHscToMinted) nonReentrant {
        s_HSCMinted[msg.sender] += amountHscToMinted;
        // If they minted too much ($150 HSC, $100 ETH)
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_hsc.mint(msg.sender, amountHscToMinted);
        if (!minted) {
            revert HSCEngine__MintedFailed();
        }
    }


    function burnHsc(uint256 amount) public moreThanZero(amount) {
        s_HSCMinted[msg.sender] -= amount;

        bool success = i_hsc.transferFrom(msg.sender, address(this).balance, amount);
        if (!success) {
            revert HSCEngine__TransferFailed();
        }
        i_hsc.burn(amount);
        _revertIfHealthFactorIsBroken(msg.sender); // I don't think this would ever hit
    }

    /*
     * @param collateral: The ERC20 token address of the collateral you're using to make the protocol solvent again.
     * This is collateral that you're going to take from the user who is insolvent.
     * In return, you have to burn your HSC to pay off their debt, but you don't pay off your own.
     * @param user: The user who is insolvent. They have to have a _healthFactor below MIN_HEALTH_FACTOR
     * @param debtToCover: The amount of HSC you want to burn to cover the user's debt.
     *
     * @notice: You can partially liquidate a user.
     * @notice: You will get a 10% LIQUIDATION_BONUS for taking the users funds.
     * @notice: This function working assumes that the protocol will be roughly 150% overcollateralized in order for this to work.
     * @notice: A known bug would be if the protocol was only 100% collateralized, we wouldn't be able to liquidate anyone.
     * For example, if the price of the collateral plummeted before anyone could be liquidated.
     */
    function liquidate(address collateral, address user, uint256 debtToCover) 
    external moreThanZero(debtToCover) nonReentrant {
        
    }
    
    function getHealthFactor() external {}

    //////////////////////////////////////////
    // Private & Internal View Functions    //
    //////////////////////////////////////////

    // checking if the minted to much ($150 HSC, $100 ETH)
    function _revertIfHealthFactorIsBroken(address user) internal view {
        // 1. Check health factor (do they have enough collateral?)
        // 2. Revert if they don't
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert HSCEngine__BreakHealthFactor(userHealthFactor);
        }
    }

    //////////////////////////////////////////
    // Private & Internal view Functions    //
    //////////////////////////////////////////

    /*
    * Retrun how close to liquidate a user is
    * If a user gose below 1, They can get liquidated
    */ 
    function _healthFactor(address user) private view returns(uint256) {
        // Total Hsc minted
        // Total collateral value
        (uint256 totalHscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);

        // It's essentially determining the minimum value of collateral required to avoid liquidation.
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;

        // This indicates how much collateral the user has relative to the stablecoins they've minted. 
        // Higher values indicate a safer position.
        return (collateralAdjustedForThreshold * PRECISION) / totalHscMinted;
    }

    function _getAccountInformation(address user) 
    private view returns(uint256 totalHscMinted, uint256 collateralValueInUsd) {
        totalHscMinted = s_HSCMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }


    /////////////////////////////////////////////////
    // Public & External View & Pure Functions     //
    /////////////////////////////////////////////////

    function getAccountCollateralValue(address user) public view returns(uint256 totalCollateralValueInUsd) {
        // loop thorough each collateral tokens get the amount they have deposited 
        // and map it to the price, to get the Usd value

        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }

        return totalCollateralValueInUsd;
    }



    function getUsdValue(address token, uint256 amount) 
    public view returns(uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // 1 ETH = 1000 USD
        // The returned value from Chainlink will be 1000 * 1e8
        // Most USD pairs have 8 decimals, so we will just pretend they all do
        // We want to have everything in terms of WEI, so we add 10 zeros at the end
        return ((uint256(price) * ADITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }
}