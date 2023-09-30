// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IArena {
    function token() external view returns (address);

    function arenaFee() external view returns (uint256);

    function topicCreationFee() external view returns (uint256);

    function choiceCreationFee() external view returns (uint256);

    function funds() external view returns (address);
}
