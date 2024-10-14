// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Assignment2.sol";

contract DutchAuction is IDutchAuction {
    // Public variables
    address public seller;
    address public winner;
    uint256 public finalPrice;

    // Private variables
    uint256 private initialPrice;
    uint256 private blockDecrement;
    uint256 private endBlock;
    uint256 private startBlock;

    // Tracks if auction has ended
    bool private finalized;

    // Note: Contract creator should be the seller
    constructor(
        uint256 _initialPrice,  
        uint256 _blockDecrement,
        uint256 _duration
    ) {
        require(_initialPrice > 0, "Initial price must be greater than 0");
        require(_blockDecrement > 0, "Block decrement must be greater than 0");
        require(_duration > 0, "Duration must be greater than 0");

        seller = msg.sender;
        initialPrice = _initialPrice;
        blockDecrement = _blockDecrement;
        startBlock = block.number;
        endBlock = startBlock + _duration - 1;
    }

    // Used for placing bids on the auction
    // Winner is whoever first places a valid bid with a value equal to or higher than the current price
    function bid() external payable override {
        require(block.number <= endBlock, "Auction has ended");
        require(winner == address(0), "Auction already has a winner");

        uint256 price = currentPrice();
        require(price > 0, "Auction has ended");
        require(msg.value >= price, "Bid is too low");

        winner = msg.sender;
        finalPrice = price;

        // Refund the excess amount when the bid is higher than the current price
        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }
    }

    // Anyone can use this function to finalize the auction after the auction has ended
    function finalize() external override {
        require(block.number > endBlock || winner != address(0), "Auction has not yet ended");
        require(!finalized, "Auction is already finalized");

        finalized = true;

        if (winner != address(0)) {
            payable(seller).transfer(finalPrice);
        }
    }

    // This function calculates the current price of the item
    function currentPrice() public view override returns (uint256) {
        if (block.number > endBlock) {
            return 0;
        }

        // How many blocks have passed
        uint256 elapsedBlocks = block.number - startBlock;
        uint256 totalDecrement = elapsedBlocks * blockDecrement;

        if (totalDecrement >= initialPrice) {
            return 0;
        }

        return initialPrice - totalDecrement;
    }
}
