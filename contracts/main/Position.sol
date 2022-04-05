// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Topic.sol";

library PositionUtils {
    function updatePosition(
        Position storage p,
        Topic memory topic,
        uint256 amount
    ) internal {
        // update user postion data
        p.checkPointShares = getShares(p, topic);
        p.tokens += amount;
        p.blockNumber = block.number;
    }

    function getShares(Position memory p, Topic memory t)
        internal
        view
        returns (uint256)
    {
        // cycles passed
        uint256 shares;
        uint256 cyclesPassed = (block.number - p.blockNumber) /
            t._cycleDuration;
        shares =
            p.tokens *
            cyclesPassed *
            (t._sharePerCyclePercentage / 10000) +
            p.checkPointShares;

        return shares;
    }
}

struct Position {
    // share are dynamically calculated as follows
    // tokensInvested * (rate*cyclesInPosition) + checkPointShares
    uint256 tokens; // current number of tokens in position
    uint256 blockNumber; // the last block that user changed it's position
    uint256 checkPointShares; // for history keeping after user changes the amount of tokens in position
}
