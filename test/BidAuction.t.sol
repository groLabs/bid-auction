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

    function testRunAuctionHappy(uint256 _minBid, uint96 _auctionAmount) public {
        _minBid = bound(_minBid, 1e18, 1000e18);
        _auctionAmount = uint96(bound(_auctionAmount, 1e6, 100_000_000e6));
        BidAuction auction = _createAuction(_auctionAmount, _minBid);

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
        auction.bid{ value: _minBid * 2 }();
        uint256 aliceEthBalanceSnapshot = alice.balance;
        // Make sure highest bid and bidder are set
        assertEq(auction.highestBid(), _minBid * 2);
        assertEq(auction.highestBidder(), alice);

        // Make sure alice's bid is set
        assertEq(auction.bids(alice), _minBid * 2);

        // Bob wants to bid
        vm.prank(bob);
        auction.bid{ value: _minBid * 3 }();

        // Make sure highest bid and bidder are set
        assertEq(auction.highestBid(), _minBid * 3);

        // Make sure bob's bid is set
        assertEq(auction.bids(bob), _minBid * 3);
        vm.prank(bob);
        // As Bob is the highest bidder, she can't withdraw
        vm.expectRevert("highest bidder can't withdraw");
        auction.withdraw();
        // End auction and alice gets USDC
        vm.warp(block.timestamp + 7 days + 1);
        auction.end();

        // Make sure USDC is transferred to bob
        assertEq(USDC.balanceOf(alice), 0);
        assertEq(USDC.balanceOf(bob), _auctionAmount);

        // Alice can withdraw now
        vm.prank(alice);
        auction.withdraw();
        // Make sure alice gets her ETH back
        assertEq(alice.balance, aliceEthBalanceSnapshot + _minBid * 2);
    }

    function testRunAuctionNoBidders(uint256 _minBid, uint96 _auctionAmount) public {
        _minBid = bound(_minBid, 1e18, 1000e18);
        _auctionAmount = uint96(bound(_auctionAmount, 1e6, 100_000_000e6));
        BidAuction auction = _createAuction(_auctionAmount, _minBid);

        // Give USDC to basedAdmin
        setStorage(basedAdmin, USDC.balanceOf.selector, address(USDC), type(uint96).max);
        uint256 balanceSnapshot = USDC.balanceOf(basedAdmin);
        vm.startPrank(basedAdmin);
        // Approve auction to spend USDC
        USDC.approve(address(auction), type(uint96).max);
        // Start auction
        auction.start();
        assertEq(USDC.balanceOf(basedAdmin), balanceSnapshot - _auctionAmount);
        assertEq(auction.started(), true);
        vm.stopPrank();

        // End auction and owner gets USDC back, since there were no bidders
        vm.warp(block.timestamp + 7 days + 1);
        auction.end();
        // Make sure owner get USDC back
        assertEq(USDC.balanceOf(basedAdmin), balanceSnapshot);
    }

    function testCantWithdrawHighestBid(uint256 _minBid, uint96 _auctionAmount) public {
        _minBid = bound(_minBid, 1e18, 1000e18);
        _auctionAmount = uint96(bound(_auctionAmount, 1e6, 100_000_000e6));
        BidAuction auction = _createAuction(_auctionAmount, _minBid);

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
        auction.bid{ value: _minBid * 2 }();

        // Make sure highest bid and bidder are set
        assertEq(auction.highestBid(), _minBid * 2);
        assertEq(auction.highestBidder(), alice);

        vm.prank(alice);
        // As Alice is the highest bidder, she can't withdraw
        vm.expectRevert("highest bidder can't withdraw");
        auction.withdraw();
    }
}
