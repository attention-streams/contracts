// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./interfaces/IArena.sol";
import "./Topic.sol";

contract Arena is IArena {
    uint256 public constant FEE_SCALE = 10000;
    uint256 public immutable arenaFee;
    address public immutable funds; // arena fees are sent here
    address public immutable token;

    address[] public topics;

    event TopicDeployed(address indexed topic, address indexed creator);

    error InvalidFee();

    constructor(uint256 _arenaFee, address _funds, address _token) {
        if (_arenaFee > FEE_SCALE) revert InvalidFee();

        arenaFee = _arenaFee;
        funds = _funds;
        token = _token;
    }

    function getTopicsLength() external view returns (uint256) {
        return topics.length;
    }

    function deployTopic(
        uint256 _startTime,
        uint256 _cycleDuration,
        uint256 _totalCycles,
        uint256 _accrualRate,
        uint256 _contributorFee,
        uint256 _topicFee,
        address _funds
    ) external {
        if (_contributorFee + _topicFee + arenaFee > FEE_SCALE) revert InvalidFee();
        address newTopic = address(
            new Topic(
                _startTime,
                _cycleDuration,
                _totalCycles,
                _accrualRate,
                _contributorFee,
                _topicFee,
                _funds,
                address(this)
            )
        );
        topics.push(newTopic);

        emit TopicDeployed(newTopic, msg.sender);
    }
}
