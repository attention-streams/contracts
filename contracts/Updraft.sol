// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Updraft is Ownable {
    using SafeERC20 for IERC20;

    /// @notice Allow up to 2 decimal places for percentages.
    /// Examples: 100% = 10000 , 25.34% = 2534
    uint256 public constant PERCENT_SCALE = 100;

    IERC20 public feeToken;
    uint256 public minFee;
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
}
