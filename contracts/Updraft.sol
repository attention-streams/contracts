// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Updraft is Ownable {
    using SafeERC20 for IERC20;

    /// Allow 2 decimal places for percentages.
    /// Examples: 100% = 10000 , 25.34% = 2534
    uint256 public constant PERCENT_SCALE = 100;

    IERC20 public feeToken;

    /// `minFee` is the minimum fee (in `feeToken`) paid for creating or contributing to an idea,
    /// and the only fee paid for creating solutions and updating profiles.
    uint256 public minFee;

    /// `percentFee` is the percentage used to calculate the feed paid for creating or contributing to an idea.
    /// It's multiplied by the contribution amount and the fee paid is the greater of the result and `minFee`.
    /// It uses `PERCENT_SCALE` for precision.
    uint256 public percentFee;

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

    constructor(IERC20 feeToken_, minFee_, percentFee_){
        feeToken = feeToken_;
        minFee = minFee_;
        percentFee = percentFee_;
    }

    function setMinFee(uint256 amount) external onlyOwner {
        minFee = amount;
    }

    function setPercentFee(uint256 amount) external onlyOwner {
        percentFee = amount;
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
