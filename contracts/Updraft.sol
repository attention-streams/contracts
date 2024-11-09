// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {ICrowdFund} from "./interfaces/ICrowdFund.sol";

contract Updraft is Ownable, ICrowdFund {
    using SafeERC20 for IERC20;

    uint256 public constant percentScale = 1000000;

    IERC20 public feeToken;
    uint256 public minFee;
    uint256 public percentFee;
    uint256 public accrualRate;
    uint256 public cycleLength;

    event ProfileUpdated(address indexed owner, bytes32 data);
    event IdeaCreated(
        address indexed idea,
        address indexed creator,
        uint256 contributorFee,
        uint256 contribution,
        bytes32 data
    );
    event SolutionCreated(
        string indexed _ideaId,
        address indexed solution,
        address indexed creator,
        string ideaId,
        uint256 deadline,
        uint256 goal,
        uint256 contributorFee,
        uint256 stake,
        address token,
        bytes32 data
    );

    constructor(IERC20 feeToken_, minFee_, percentFee_, cycleLength_, accrualRate_){
        feeToken = feeToken_;
        minFee = minFee_;
        percentFee = percentFee_;
        cycleLength = cycleLength_;
        accrualRate = accrualRate_;
    }

    function setFeeToken(IERC20 token) external onlyOwner {
        feeToken = token;
    }

    function setMinFee(uint256 fee) external onlyOwner {
        minFee = fee;
    }

    function setPercentFee(uint256 fee) external onlyOwner {
        percentFee = fee;
    }

    function setCycleLength(uint256 length) external onlyOwner {
        cycleLength = length;
    }

    function setAccrualRate(uint256 rate) external onlyOwner {
        accrualRate = rate;
    }

    /// Create or update a profile. It will be associated with the caller's address.
    function updateProfile(bytes calldata profileData) external {
        feeToken.safeTransferFrom(msg.sender, address(0), minFee);
        emit ProfileUpdated(msg.sender, profileData);
    }

    function createIdea(uint256 contributorFee, uint256 contribution, bytes calldata ideaData) external {
        uint256 fee = max(minFee, contribution * percentFee / PERCENT_SCALE);

        feeToken.safeTransferFrom(msg.sender, address(0), fee);

    }

    function createSolution() external {
        feeToken.safeTransferFrom(msg.sender, address(0), minFee);
    }

    /// Create or update a profile while creating an idea, to avoid paying the updraft anti-spam fee twice.
    function createIdeaWithProfile(bytes calldata profileData) external {
        emit ProfileUpdated(msg.sender, profileData);
    }

    /// Create or update a profile while creating a solution, to avoid paying `minFee` twice.
    function createSolutionWithProfile(bytes calldata profileData) external {
        feeToken.safeTransferFrom(msg.sender, address(0), minFee);
    }

}
