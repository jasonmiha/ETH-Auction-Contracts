// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Assignment2.sol";

contract VickreyAuction is IVickreyAuction {
    uint256 public reservePrice;
    uint256 public bidDeposit;
    address public seller;

    address public winner;
    uint256 public finalPrice;

    address public highestBidder;
    uint256 public secondHighestBid;

    uint256 private biddingEnd;
    uint256 private revealEnd;

    bool private finalized;


    // Note: Contract creator should be the seller
    constructor(
        uint256 _reservePrice,
        uint256 _bidDeposit,
        uint256 _biddingPeriod,
        uint256 _revealPeriod
    ) {
        require(_reservePrice > 0, "Reserve price must be greater than 0");
        require(_bidDeposit > 0, "Bid deposit must be greater than 0");
        require(_biddingPeriod > 0, "Bidding period must be greater than 0");
        require(_revealPeriod > 0, "Reveal period must be greater than 0");

        seller = msg.sender;
        reservePrice = _reservePrice;
        bidDeposit = _bidDeposit;
        biddingEnd = block.number + _biddingPeriod - 1;
        revealEnd = biddingEnd + _revealPeriod;
    }

    // Can use mapping to store the commitment for each bidder
    mapping(address => bytes32) private bidCommitments;
    mapping(address => uint256) private bidderDeposits;
    mapping(address => uint256) private revealedBids;
    mapping(address => bool) private hasRevealed;

    // Record the player's bid commitment
    // Make sure at least bidDepositAmount is provided (for new bids)
    // Bidders can update their previous bid for free if desired.
    // Only allow commitments before biddingDeadline
    function commitBid(bytes32 bidCommitment) external payable override {
        require(block.number <= biddingEnd, "Bidding period has ended");

        uint256 currentDeposit = bidderDeposits[msg.sender];
        uint256 totalDeposit = currentDeposit + msg.value;

        if (currentDeposit == 0) {
            require(totalDeposit >= bidDeposit, "Insufficient bid deposit");
        }

        bidCommitments[msg.sender] = bidCommitment;
        bidderDeposits[msg.sender] = totalDeposit;

        // Only refund if there's an excess deposit
        if (totalDeposit > bidDeposit) {
            uint256 refundAmount = totalDeposit - bidDeposit;
            bidderDeposits[msg.sender] = bidDeposit;
            payable(msg.sender).transfer(refundAmount);
        }
    }

    // Check that the bid (msg.value) matches the commitment
    // If the bid is below the minimum price, it is ignored but the deposit is returned.
    // If the bid is below the current highest known bid, the bid value and deposit are returned.
    // If the bid is the new highest known bid, the deposit is returned and the previous high bidder's bid is returned.
    function revealBid(bytes32 nonce) external payable override {
        require(block.number > biddingEnd && block.number <= revealEnd, "Not in reveal period");
        require(!hasRevealed[msg.sender], "Bid already revealed");
        require(bidderDeposits[msg.sender] >= bidDeposit, "No valid bid committed");

        bytes32 commitment = makeCommitment(msg.value, nonce);
        require(commitment == bidCommitments[msg.sender], "Incorrect bid or nonce");

        hasRevealed[msg.sender] = true;
        revealedBids[msg.sender] = msg.value;

        uint256 refundAmount = bidderDeposits[msg.sender];

        if (msg.value >= reservePrice && msg.value > revealedBids[highestBidder]) {
            if (highestBidder != address(0)) {
                payable(highestBidder).transfer(revealedBids[highestBidder]);
            }
            secondHighestBid = revealedBids[highestBidder];
            highestBidder = msg.sender;
            refundAmount = bidderDeposits[msg.sender]; // Only refund deposit for highest bidder
        } else {
            refundAmount += msg.value; // Refund both deposit and bid for non-highest bidders
            if (msg.value > secondHighestBid && msg.sender != highestBidder) {
                secondHighestBid = msg.value;
            }
        }

        bidderDeposits[msg.sender] = 0;

        if (refundAmount > 0) {
            payable(msg.sender).transfer(refundAmount);
        }
    }

    // This function shows how to make a commitment
    function makeCommitment(
        uint256 bidValue,
        bytes32 nonce
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(bidValue, nonce));
    }

    // Anyone can finalize the auction after the reveal period has ended
    function finalize() external override {
        require(block.number > revealEnd, "Reveal period not ended");
        require(!finalized, "Auction already finalized");

        finalized = true;
        winner = highestBidder;
        finalPrice = secondHighestBid > reservePrice ? secondHighestBid : reservePrice;

        if (winner != address(0)) {
            // Transfer final price to seller
            payable(seller).transfer(finalPrice);
            // Refund difference to winner if they bid more than second highest bid
            if (revealedBids[winner] > finalPrice) {
                payable(winner).transfer(revealedBids[winner] - finalPrice);
            }
        }
    }
}
