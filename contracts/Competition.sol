// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/ITopic.sol";
import "./interfaces/IChoice.sol";

struct ChoiceData {
    uint256 tokens;
    uint256 totalShares;
}

contract Competition {
    using SafeERC20 for IERC20;

    address public immutable topic;
    address public immutable token;
    uint256 public immutable snapshotCycle;

    mapping(address => ChoiceData) public choiceData; // choice => ChoiceData

    constructor(address _topic, uint256 _snapshotTimestamp) {
        topic = _topic;
        token = ITopic(_topic).token();
        snapshotCycle = ITopic(_topic).cycleNumberAt(_snapshotTimestamp);
    }

    /// @param choice : address of the choice
    /// @param amount : amount of tokens to contribute
    /// @param receiver : address of the receiver of the position
    function contribute(address choice, uint256 amount, address receiver) external onlyValidChoice(choice) {
        IChoice _choice = IChoice(choice);

        // receive the contribution from msg.sender
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(token).safeApprove(address(_choice), amount);

        // contribute to the choice on behalf of the receiver
        _choice.contributeFor(amount, receiver);

        // update the choiceData
        choiceData[choice] = ChoiceData({
            tokens: _choice.tokens(),
            totalShares: _choice.totalSharesAtCycle(snapshotCycle)
        });
    }

    modifier onlyValidChoice(address choice) {
        require(ITopic(topic).isChoice(choice), "INVALID_CHOICE");
        _;
    }
}
