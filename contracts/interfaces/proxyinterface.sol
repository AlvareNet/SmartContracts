// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IProxyContract {
    function preTransfer(address, address, uint256, bool) external;
    function postTransfer(address, address, uint256, bool) external;
    function getPair() external view returns (address);
}