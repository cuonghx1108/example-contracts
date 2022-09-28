// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC777/ERC777.sol)

pragma solidity ^0.8.0;

interface IPermitter {
    function isAllowed(address target) external view returns (bool);
    function approve(address holder) external;
    function isApproved(address tokenHolder) external view returns (bool);
    function prohibit(address holder) external;
    function isProhibited(address holder) external view returns (bool);

    event AuthorizedAddress(address indexed holder);
    event ProhibitedAddress(address indexed holder);
}
