// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./token.sol";
import "./interfaces/IMerkleDistributor.sol";

contract MerkleDistributor is IMerkleDistributor {
    address public immutable override token;
    AlvareNet private immutable _AlvareNet;
    bytes32 public immutable override merkleRoot;
    uint256 private immutable _startReflection;
    uint256 private constant _startToken = 1000000000;

    // This is a packed array of booleans.
    mapping(address => bool) private _claimedAddress;

    constructor(address token_, bytes32 merkleRoot_) {
        token = token_;
        _AlvareNet = AlvareNet(token_);
        _startReflection = AlvareNet(token_).reflectionFromToken(_startToken, false);
        merkleRoot = merkleRoot_;
    }

    function isClaimed(address account) public view override returns (bool) {
        return _claimedAddress[account];
    }

    function _setClaimed(address account) private {
        _claimedAddress[account] = true;
    }

    function getBalance(uint256 startAmount) public view override returns (uint256) {
        uint256 newTokenBalance = _AlvareNet.tokenFromReflection(_startReflection);
        return startAmount * newTokenBalance / _startToken;
    }

    function claim(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof) external override {
        require(!isClaimed(account), 'MerkleDistributor: Drop already claimed.');

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(index, account, amount));
        require(MerkleProof.verify(merkleProof, merkleRoot, node), 'MerkleDistributor: Invalid proof.');

        // Mark it claimed and send the token.
        _setClaimed(account);
        uint256 sendamount = getBalance(amount);
        require(IERC20(token).transfer(account, sendamount), 'MerkleDistributor: Transfer failed.');

        emit Claimed(index, account, sendamount);
    }
}