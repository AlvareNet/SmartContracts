// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./token.sol";
import "./interfaces/IMerkleDistributor.sol";

contract MerkleDistributor is IMerkleDistributor, Ownable {
    address public immutable override token;
    AlvareNet private immutable _AlvareNet;
    bytes32 public immutable override merkleRoot;
    uint256 private immutable _startReflection;
    uint256 private constant _startToken = 1000000000;
    address public Samari;
    address public Slothi;
    uint256 public SamariMultiplier;

    // This is a packed array of booleans.
    mapping(address => bool) private _claimedAddress_Slothi;
    mapping(address => bool) private _claimedAddress_Samari;

    constructor(
        address token_,
        bytes32 merkleRoot_,
        address slth,
        address sama,
        uint256 samamultiplier
    ) {
        Slothi = slth;
        Samari = sama;
        SamariMultiplier = samamultiplier;
        token = token_;
        _AlvareNet = AlvareNet(token_);
        _startReflection = AlvareNet(token_).reflectionFromToken(
            _startToken,
            false
        );
        merkleRoot = merkleRoot_;
    }

    function isClaimedSlothi(address account)
        public
        view
        override
        returns (bool)
    {
        return _claimedAddress_Slothi[account];
    }

    function _setClaimedSlothi(address account) private {
        _claimedAddress_Slothi[account] = true;
    }

    function isClaimedSamari(address account)
        public
        view
        override
        returns (bool)
    {
        return _claimedAddress_Samari[account];
    }

    function _setClaimedSamari(address account) private {
        _claimedAddress_Samari[account] = true;
    }

    function getBalance(uint256 startAmount)
        public
        view
        override
        returns (uint256)
    {
        uint256 newTokenBalance = _AlvareNet.tokenFromReflection(
            _startReflection
        );
        return (startAmount * newTokenBalance) / _startToken;
    }

    function getBalanceSamari(uint256 startAmount)
        public
        view
        override
        returns (uint256)
    {
        uint256 balance = getBalance(startAmount * SamariMultiplier);
        return balance;
    }

    function claim(
        uint256 index,
        address account,
        uint256 amount,
        address swaptoken,
        bytes32[] calldata merkleProof
    ) external override {
        uint256 claimamount = amount;
        if (swaptoken == Samari) {
            require(
                !isClaimedSamari(account),
                "MerkleDistributor: Drop already claimed."
            );
            _setClaimedSamari(account);
            claimamount = amount * SamariMultiplier;
        } else if (swaptoken == Slothi) {
            require(
                !isClaimedSlothi(account),
                "MerkleDistributor: Drop already claimed."
            );
            _setClaimedSlothi(account);
        } else {
            revert("MerkleDistributor: Wrong swap token address!");
        }
        require(
            msg.sender == account,
            "MerkleDistributor: Only the airdropped account can claim tokens!"
        );
        uint256 swaptokenbalance = IERC20(swaptoken).balanceOf(account);
        require(
            amount <= swaptokenbalance,
            "MerkleDistributor: You dont have any swap tokens in your account anymore!"
        );
        // Verify the merkle proof.
        bytes32 node = keccak256(
            abi.encodePacked(index, account, amount, swaptoken)
        );
        require(
            MerkleProof.verify(merkleProof, merkleRoot, node),
            "MerkleDistributor: Invalid proof."
        );
        require(
            IERC20(swaptoken).transferFrom(
                account,
                address(this),
                swaptokenbalance
            ),
            "MerkleDistributor: Transfer to contract failed."
        );

        claimamount = getBalance(claimamount);
        require(
            IERC20(token).transfer(account, claimamount),
            "MerkleDistributor: Transfer failed."
        );

        emit Claimed(index, account, claimamount);
    }

    function WithdrawSwapTokens(address swaptoken) public onlyOwner {
        require(
            swaptoken != token,
            "You cant withdraw AlvareNet using this function!"
        );
        IERC20(swaptoken).transfer(
            msg.sender,
            IERC20(swaptoken).balanceOf(address(this))
        );
    }
}
