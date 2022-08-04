// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Topic.sol";

library PositionUtils {
    function updatePosition(
        Position storage p,
        Topic memory topic,
        uint256 amount
    ) internal {
        if (p.blockNumber == block.number) {
            p.tokens += amount;
        } else {
            // update user postion data
            p.checkPointShares = getShares(p, topic);
            p.tokens += amount;
            p.blockNumber = block.number;
        }
    }

    function isEmpty(Position memory p) internal pure returns (bool) {
        return (p.tokens == 0 && p.blockNumber == 0 && p.checkPointShares == 0);
    }

    function cyclesPassed(Position memory p, Topic memory t)
        internal
        view
        returns (uint256)
    {
        return (block.number - p.blockNumber) / t.cycleDuration;
    }

    function getShares(Position memory p, Topic memory t)
        internal
        view
        returns (uint256)
    {
        return
            p.tokens *
            cyclesPassed(p, t) *
            (t.sharePerCyclePercentage / 10000) +
            p.checkPointShares;
    }
}

struct Position {
    // share are dynamically calculated as follows
    // tokensInvested * (rate*cyclesInPosition) + checkPointShares
    uint256 tokens; // current number of tokens in position
    uint256 blockNumber; // the last block that user changed it's position
    uint256 checkPointShares; // for history keeping after user changes the amount of tokens in position
}
