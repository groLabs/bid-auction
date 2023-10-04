// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import "../src/BidAuction.sol";
import "./Utils.sol";

contract TestBidAuction is Test {
    ERC20 public constant USDC = ERC20(address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48));
    Utils internal utils;
    address payable[] internal users;
    address public alice;
    address public bob;

    function _createAuction(uint256 _amount, uint256 _startingBid) internal returns (BidAuction) {
        BidAuction auction = new BidAuction(address(USDC), _amount, _startingBid);
        return auction;
    }

    function setUp() public {
        vm.createSelectFork("mainnet", 18_090_274);
        utils = new Utils();
        users = utils.createUsers(5);
        alice = users[0];
        vm.label(alice, "Alice");
        bob = users[1];
        vm.label(bob, "Bob");
    }

    function testSetupAuction() public {
        BidAuction auction = _createAuction(1000e6, 1e18);
        assertEq(address(auction.asset()), address(USDC));
        assertEq(auction.amount(), 1000e6);
        assertEq(auction.highestBid(), 1e18);
    }
}
