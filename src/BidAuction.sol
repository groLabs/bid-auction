// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract BidAuction {
    using SafeERC20 for ERC20;

    event Start();
    event Bid(address indexed sender, uint256 amount);
    event Withdraw(address indexed bidder, uint256 amount);
    event End(address winner, uint256 amount);

    ERC20 public immutable asset;
    uint256 public immutable amount;

    address payable public seller;
    uint256 public endAt;
    bool public started;
    bool public ended;

    address public previousHighestBidder;
    uint256 public previousHighestBid;
    address public highestBidder;
    uint256 public highestBid;
    mapping(address => uint256) public bids;

    constructor(address _asset, uint256 _amount, uint256 _startingBid) {
        asset = ERC20(_asset);
        amount = _amount;

        seller = payable(msg.sender);
        highestBid = _startingBid;
    }

    function start() external {
        require(!started, "started");
        require(msg.sender == seller, "not seller");

        asset.transferFrom(msg.sender, address(this), amount);
        started = true;
        endAt = block.timestamp + 7 days;

        emit Start();
    }

    function bid() external payable {
        require(started, "not started");
        require(block.timestamp < endAt, "ended");
        require(msg.value > highestBid, "value < highest");

        if (highestBidder != address(0)) {
            bids[highestBidder] += highestBid;
        }
        previousHighestBidder = highestBidder;
        previousHighestBid = highestBid;

        highestBidder = msg.sender;
        highestBid = msg.value;

        emit Bid(msg.sender, msg.value);
    }

    function withdraw() external {
        uint256 bal = bids[msg.sender];
        bids[msg.sender] = 0;
        payable(msg.sender).transfer(bal);
        // If bal was the highest bid, reset highestBidder and highestBid
        if (msg.sender == highestBidder) {
            highestBidder = previousHighestBidder;
            highestBid = previousHighestBid;
        }
        emit Withdraw(msg.sender, bal);
    }

    function end() external {
        require(started, "not started");
        require(block.timestamp >= endAt, "not ended");
        require(!ended, "ended");

        ended = true;
        if (highestBidder != address(0)) {
            asset.safeTransferFrom(address(this), highestBidder, amount);
            seller.transfer(highestBid);
        } else {
            asset.safeTransferFrom(address(this), seller, amount);
        }

        emit End(highestBidder, highestBid);
    }
}
