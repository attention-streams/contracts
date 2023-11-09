// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./Choice.sol";
import "./interfaces/IArena.sol";
import "./interfaces/ITopic.sol";
import "./interfaces/IChoice.sol";

contract Topic is ITopic {
    using SafeERC20 for IERC20;

    uint256 public immutable startTime;
    uint256 public immutable cycleDuration;
    uint256 public immutable accrualRate;
    uint256 public immutable contributorFee;
    uint256 public immutable topicFee;
    uint256 public immutable choiceCreationFee; // to prevent spam
    address public immutable arenaFunds;
    address public immutable funds;
    address public immutable arena;
    address public immutable token;
    uint32 public immutable snapshotDuration; // in terms of cycles
    string public metadataURI; // string cannot be marked as immutable, however it is never modified after construction

    address[] public choices;
    mapping(address => bool) isChoice;

    event ChoiceDeployed(address indexed choice, address indexed creator);

    constructor(
        uint256 _startTime,
        uint256 _cycleDuration,
        uint256 _accrualRate,
        uint256 _contributorFee,
        uint256 _topicFee,
        address _funds,
        address _arena,
        uint32 _snapshotDuration,
        string memory _metadataURI
    ) {
        IArena arena_ = IArena(_arena);

        startTime = _startTime;
        cycleDuration = _cycleDuration;
        accrualRate = _accrualRate;
        contributorFee = _contributorFee;
        topicFee = _topicFee;
        choiceCreationFee = arena_.choiceCreationFee();
        arenaFunds = arena_.funds();
        token = arena_.token();
        funds = _funds;
        arena = _arena;
        snapshotDuration = _snapshotDuration;
        metadataURI = _metadataURI;
    }

    function deployChoice(string memory _metadataURI) external {
        address newChoice = address(new Choice(_metadataURI));
        choices.push(newChoice);
        isChoice[newChoice] = true;

        IERC20(token).safeTransferFrom(msg.sender, arenaFunds, choiceCreationFee);
        emit ChoiceDeployed(newChoice, msg.sender);
    }

    function choicesLength() public view returns (uint256) {
        return choices.length;
    }

    function currentCycleNumber() external view returns (uint256) {
        return (block.timestamp - startTime) / cycleDuration;
    }
}
