// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Assignment2.sol";

contract DutchAuction is IDutchAuction {
    address public seller;
    address public winner;
    uint256 public finalPrice;

    uint256 private initialPrice;
    uint256 private blockDecrement;
    uint256 private endBlock;
    uint256 private startBlock;

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

    function bid() external payable override {
        require(block.number <= endBlock, "Auction has ended");
        require(winner == address(0), "Auction already has a winner");

        uint256 price = currentPrice();
        require(price > 0, "Auction has ended");
        require(msg.value >= price, "Bid is too low");

        winner = msg.sender;
        finalPrice = price;

        // Refund excess amount if bid is higher than current price
        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }
    }

    // Anyone can finalize the auction after the auction has ended
    function finalize() external override {
        require(block.number > endBlock || winner != address(0), "Auction not yet ended");
        require(!finalized, "Auction already finalized");

        finalized = true;

        if (winner != address(0)) {
            payable(seller).transfer(finalPrice);
        }
    }

    function currentPrice() public view override returns (uint256) {
        if (block.number > endBlock) {
            return 0;
        }

        uint256 elapsedBlocks = block.number - startBlock;
        uint256 totalDecrement = elapsedBlocks * blockDecrement;

        if (totalDecrement >= initialPrice) {
            return 0;
        }

        return initialPrice - totalDecrement;
    }
}
