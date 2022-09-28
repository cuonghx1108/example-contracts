// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (token/ERC777/IERC777Recipient.sol)
pragma solidity ^0.8.0;

/**
 * @title Simple777Recipient
 * @dev Very simple ERC777 Recipient
 */
interface IFeeCalculater {
  function calculateFee(uint256 amount) external view returns (uint256);
}
