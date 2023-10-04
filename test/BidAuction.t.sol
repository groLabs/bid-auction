// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BidAuction.sol";
import "./Utils.sol";

contract TestBidAuction is Test {
    using stdStorage for StdStorage;

    ERC20 public constant USDC = ERC20(address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48));
    Utils internal utils;
    address payable[] internal users;
    address public alice;
    address public bob;
    address public basedAdmin;

    function setStorage(address _user, bytes4 _selector, address _contract, uint256 value) public {
        uint256 slot = stdstore.target(_contract).sig(_selector).with_key(_user).find();
        vm.store(_contract, bytes32(slot), bytes32(value));
    }

    function _createAuction(uint256 _amount, uint256 _startingBid) internal returns (BidAuction) {
        BidAuction auction = new BidAuction(address(USDC), _amount, _startingBid, basedAdmin);
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
        basedAdmin = users[2];
        vm.label(basedAdmin, "BasedAdmin");
    }

    function testSetupAuction() public {
        BidAuction auction = _createAuction(1000e6, 1e18);
        assertEq(address(auction.asset()), address(USDC));
        assertEq(auction.amount(), 1000e6);
        assertEq(auction.highestBid(), 1e18);
        // Give USDC to basedAdmin
        setStorage(basedAdmin, USDC.balanceOf.selector, address(USDC), type(uint96).max);

        vm.startPrank(basedAdmin);
        // Approve auction to spend USDC
        USDC.approve(address(auction), type(uint96).max);
        // Start auction
        auction.start();
        assertEq(auction.started(), true);
        vm.stopPrank();
    }

    function testRunAuctionHappy() public {
        BidAuction auction = _createAuction(1000e6, 1e18);

        // Give USDC to basedAdmin
        setStorage(basedAdmin, USDC.balanceOf.selector, address(USDC), type(uint96).max);

        vm.startPrank(basedAdmin);
        // Approve auction to spend USDC
        USDC.approve(address(auction), type(uint96).max);
        // Start auction
        auction.start();
        assertEq(auction.started(), true);
        vm.stopPrank();

        // Now start bidding
        vm.prank(alice);
        auction.bid{ value: 2e18 }();

        // Make sure highest bid and bidder are set
        assertEq(auction.highestBid(), 2e18);
        assertEq(auction.highestBidder(), alice);

        // Make sure alice's bid is set
        assertEq(auction.bids(alice), 2e18);

        // Bob wants to bid
        vm.prank(bob);
        auction.bid{ value: 3e18 }();

        // Make sure highest bid and bidder are set
        assertEq(auction.highestBid(), 3e18);

        // Make sure bob's bid is set
        assertEq(auction.bids(bob), 3e18);

        // End auction and alice gets USDC
        vm.warp(block.timestamp + 7 days + 1);
        auction.end();

        // Make sure USDC is transferred to bob
        assertEq(USDC.balanceOf(alice), 0);
        assertEq(USDC.balanceOf(bob), 1000e6);
    }
}
