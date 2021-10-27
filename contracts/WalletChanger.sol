// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract WalletChanger is AccessControlEnumerable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bool public paused = true;

    event ChangeWallet(address indexed _from, address indexed _to, uint256 _value);
    IERC20 public AlvareNet;
    constructor(address _AlvareNet){
        AlvareNet = IERC20(_AlvareNet);
    }

    function setPause(bool _newState) external onlyRole(DEFAULT_ADMIN_ROLE){
        paused = _newState;
    }

    function transfer(address _newWallet) external nonReentrant() {
        require(paused, "This contract is currently paused!");
        require(_newWallet != address(0), "You cant transfer to this address!");
        require(tx.origin == msg.sender, "This contract cant be called from a smart contract");
        uint256 balance = AlvareNet.balanceOf(msg.sender);
        AlvareNet.safeTransferFrom(msg.sender, address(this), balance);
        AlvareNet.safeTransferFrom(address(this), _newWallet, balance);
        emit ChangeWallet(msg.sender, _newWallet, balance);
    }
}
