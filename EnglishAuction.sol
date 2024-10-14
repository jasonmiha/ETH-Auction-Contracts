// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Assignment2.sol";

contract EnglishAuction is IEnglishAuction {
    // Public vars
    uint256 public minIncrement;
    address public seller;
    address public winner;
    uint256 public finalPrice;
    address public highestBidder;
    uint256 public highestBid;

    // Private vars
    uint256 private initialPrice;
    uint256 private endBlock;
    uint256 private biddingPeriod;

    bool private finalized;

    // Note: Contract creator should be the seller
    constructor(
        uint256 _initialPrice,
        uint256 _minIncrement,
        uint256 _biddingPeriod
    ) {
        require(_initialPrice > 0, "Initial price must be greater than 0");
        require(_minIncrement > 0, "Minimum increment must be greater than 0");
        require(_biddingPeriod > 0, "Bidding period must be greater than 0");

        seller = msg.sender;
        initialPrice = _initialPrice;
        minIncrement = _minIncrement;
        biddingPeriod = _biddingPeriod;
        endBlock = block.number + _biddingPeriod;
    }

    // This function allows users to place bids
    function bid() external payable override {
        require(block.number < endBlock, "The auction has ended");
        require(!finalized, "The auction has been finalized");
        
        uint256 minValidBid = highestBid > 0 ? highestBid + minIncrement : initialPrice;
        require(msg.value >= minValidBid, "Bid too low");

        if (highestBidder != address(0)) {
            payable(highestBidder).transfer(highestBid);
        }

        // Update highest bidder and highest bid
        highestBidder = msg.sender;
        highestBid = msg.value;

        // Reset the bidding period
        endBlock = block.number + biddingPeriod;
    }

    // Anyone can finalize the auction after the bidding period has ended
    function finalize() external override {
        require(block.number >= endBlock, "Auction has not ended yet");
        require(!finalized, "Auction has already been finalized");

        finalized = true;
        winner = highestBidder;
        finalPrice = highestBid;

        // Give the highest bid to the seller if there is a winner
        if (winner != address(0)) {
            payable(seller).transfer(highestBid);
        }
    }
}
