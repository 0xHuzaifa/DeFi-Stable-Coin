// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

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
// view & pure functions
pragma solidity ^0.8.19;

import {ERC20Burnable, ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/*
 * @title HuzaifaStableCoin
 * @author Huzaifa Ahmed
 * Collateral: Exogenous
 * Minting (Stabilit+y Mechanism): Decentralized (Algorithmic)
 * Value (Relative Stability): Anchored (Pegged to USD)
 * Collateral Type: Crypto
 *
 * This is the contract meant to be owned by DSCEngine. It is a ERC20 token that can be minted and burned by the DSCEngine smart contract.
 */

contract HuzaifaStableCoin is ERC20Burnable, Ownable(msg.sender) {

    error HuzaifaStableCoin__AmountMustBeMoreThanZero();
    error HuzaifaStableCoin__BurnAmountExeedsBalance();
    error HuzaifaStableCoin__AddressShouldNotBeZero();

    constructor() ERC20("HuzaifaStableCoin", "HSC") {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if(_amount <= 0) {
            revert HuzaifaStableCoin__AmountMustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert HuzaifaStableCoin__BurnAmountExeedsBalance();
        }

        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert HuzaifaStableCoin__AddressShouldNotBeZero();
        }
        if (_amount >= 0) {
            revert HuzaifaStableCoin__AmountMustBeMoreThanZero();
        }
        _mint(_to, _amount);

        return true;
    }


}