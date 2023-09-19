// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./interfaces/ITopic.sol";
import "./Choice.sol";

contract Topic is ITopic {
    uint256 public immutable startTime;
    uint256 public immutable cycleDuration;
    uint256 public immutable accrualRate;
    uint256 public immutable contributorFee;
    uint256 public immutable topicFee;
    address public immutable funds;
    address public immutable arena;
    string public metadataURI; // string cannot be marked as immutable, however it is never modified after construction

    address[] public choices;

    event ChoiceDeployed(address indexed choice, address indexed creator);

    constructor(
        uint256 _startTime,
        uint256 _cycleDuration,
        uint256 _accrualRate,
        uint256 _contributorFee,
        uint256 _topicFee,
        address _funds,
        address _arena,
        string memory _metadataURI
    ) {
        startTime = _startTime;
        cycleDuration = _cycleDuration;
        accrualRate = _accrualRate;
        contributorFee = _contributorFee;
        topicFee = _topicFee;
        funds = _funds;
        arena = _arena;
        metadataURI = _metadataURI;
    }

    function deployChoice(string memory _metadataURI) external {
        address newChoice = address(new Choice(address(this), _metadataURI));
        choices.push(newChoice);

        emit ChoiceDeployed(newChoice, msg.sender);
    }

    function choicesLength() public view returns (uint256) {
        return choices.length;
    }

    function currentCycleNumber() external view returns (uint256) {
        return (block.timestamp - startTime) / cycleDuration;
    }
}
