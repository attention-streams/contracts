pragma solidity ^0.8.0;

struct Position {
    // share are dynamically calculated as follows
    // tokensInvested * (rate*cyclesInPosition) + checkPointShares
    uint256 tokens; // current number of tokens in position
    uint256 blockNumber; // the last block that user changed it's position
    uint256 checkPointShares; // for history keeping after user changes the amount of tokens in position
}
