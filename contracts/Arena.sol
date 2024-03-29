// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/IArena.sol";
import "./Topic.sol";

contract Arena is IArena {
    using SafeERC20 for IERC20;

    uint256 public constant FEE_SCALE = 10000;
    uint256 public immutable arenaFee;
    uint256 public immutable topicCreationFee; // to prevent spam
    uint256 public immutable choiceCreationFee; // to prevent spam
    address public immutable funds; // arena fees are sent here
    address public immutable token;
    string public metadataURI; // string cannot be marked as immutable, however it is never modified after construction

    address[] public topics;

    event TopicDeployed(address indexed topic, address indexed creator);

    error InvalidFee();

    constructor(
        uint256 _arenaFee,
        uint256 _topicCreationFee,
        uint256 _choiceCreationFee,
        address _funds,
        address _token,
        string memory _metadataURI
    ) {
        if (_arenaFee > FEE_SCALE) revert InvalidFee();

        arenaFee = _arenaFee;
        funds = _funds;
        token = _token;
        metadataURI = _metadataURI;

        topicCreationFee = _topicCreationFee;
        choiceCreationFee = _choiceCreationFee;
    }

    function getTopicsLength() external view returns (uint256) {
        return topics.length;
    }

    /// @notice deploys a new topic
    /// @param _startTime : timestamp of the first cycle
    /// @param _cycleDuration : duration of each cycle
    /// @param _accrualRate : rate at which the shares grow inside the topic, check the docs for more info
    /// @param _contributorFee : fee taken from the contributor's vote and sent to the previous contributor
    /// @param _topicFee : fee taken from the contributor's vote and sent to the topic
    /// @param _funds: address of the funds contract
    /// @param _metadataURI: metadata URI of the topic, pass an empty string to use the default URI
    function deployTopic(
        uint256 _startTime,
        uint256 _cycleDuration,
        uint256 _accrualRate,
        uint256 _contributorFee,
        uint256 _topicFee,
        address _funds,
        string memory _metadataURI
    ) external {
        if (_contributorFee + _topicFee + arenaFee > FEE_SCALE) revert InvalidFee();
        address newTopic = address(
            new Topic(
                _startTime,
                _cycleDuration,
                _accrualRate,
                _contributorFee,
                _topicFee,
                _funds,
                address(this),
                _metadataURI
            )
        );

        topics.push(newTopic);

        IERC20(token).safeTransferFrom(msg.sender, funds, topicCreationFee);

        emit TopicDeployed(newTopic, msg.sender);
    }
}
