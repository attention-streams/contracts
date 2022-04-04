pragma solidity ^0.8.0;

struct Position {
    address voter;
    uint256 tokens;
    uint256 shares;
    uint256 checkPointShares; // for history keeping after user changes the amount of tokens in position
    uint256 checkPointBlockNumber; // the last block that user changed it's position
}