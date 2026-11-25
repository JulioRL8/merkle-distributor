// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

contract MerkleDistributor {
    error InvalidRoot();
    error EmptyFunding();
    error InvalidClaim();
    error AlreadyClaimed();
    error InvalidProof();
    error TransferFailed();

    bytes32 public immutable root;
    mapping(address account => bool) public claimed;

    event Claimed(address indexed account, address indexed recipient, uint256 amount);

    constructor(bytes32 merkleRoot) payable {
        if (merkleRoot == bytes32(0)) revert InvalidRoot();
        if (msg.value == 0) revert EmptyFunding();
        root = merkleRoot;
    }

    function claim(uint256 amount, bytes32[] calldata proof, address payable recipient) external {
        if (amount == 0) revert InvalidClaim();
        if (recipient == address(0)) revert InvalidClaim();
        if (claimed[msg.sender]) revert AlreadyClaimed();

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, amount))));
        if (_computeRoot(leaf, proof) != root) revert InvalidProof();

        claimed[msg.sender] = true;
        emit Claimed(msg.sender, recipient, amount);
        (bool sent,) = recipient.call{value: amount}("");
        if (!sent) revert TransferFailed();
    }

    function _computeRoot(bytes32 node, bytes32[] calldata proof) private pure returns (bytes32) {
        for (uint256 i; i < proof.length; ++i) {
            bytes32 sibling = proof[i];
            if (node < sibling) {
                node = keccak256(abi.encodePacked(node, sibling));
            } else {
                node = keccak256(abi.encodePacked(sibling, node));
            }
        }
        return node;
    }
}
