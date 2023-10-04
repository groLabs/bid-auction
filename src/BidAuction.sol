// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract BidAuction is Ownable {
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

    address public highestBidder;
    uint256 public highestBid;
    mapping(address => uint256) public bids;

    /// @notice Instantiate auction
    constructor(address _asset, uint256 _amount, uint256 _startingBid, address _owner) Ownable() {
        asset = ERC20(_asset);
        amount = _amount;

        seller = payable(_owner);
        highestBid = _startingBid;
        // Transfer ownership to msig or whatever
        _transferOwnership(_owner);
    }

    /// @notice Start auction and transfer asset to contract
    function start() external onlyOwner {
        require(!started, "started");

        asset.transferFrom(msg.sender, address(this), amount);
        started = true;
        endAt = block.timestamp + 7 days;

        emit Start();
    }

    /// @notice Bid on auction with ETH
    function bid() external payable {
        require(started, "not started");
        require(block.timestamp < endAt, "ended");

        uint256 bal = bids[msg.sender];
        require(msg.value + bal > highestBid, "value < highest");

        highestBidder = msg.sender;
        highestBid = msg.value;
        bids[msg.sender] += msg.value;

        emit Bid(msg.sender, msg.value);
    }

    /// @notice Withdraw bid if not highest bidder
    function withdraw() external {
        require(msg.sender != highestBidder, "highest bidder can't withdraw");
        uint256 bal = bids[msg.sender];
        // Don't allow to withdraw if bidder is the highest bidder
        bids[msg.sender] = 0;
        payable(msg.sender).transfer(bal);
        emit Withdraw(msg.sender, bal);
    }

    /// @notice End auction and transfer asset to highest bidder. If there were no bidders, transfer asset back to
    /// seller
    function end() external {
        require(started, "not started");
        require(block.timestamp >= endAt, "not ended");
        require(!ended, "ended");

        ended = true;
        if (highestBidder != address(0)) {
            asset.safeTransfer(highestBidder, amount);
            seller.transfer(highestBid);
        } else {
            asset.transfer(seller, amount);
        }

        emit End(highestBidder, highestBid);
    }
}
