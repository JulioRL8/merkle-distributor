// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {MerkleDistributor} from "../src/MerkleDistributor.sol";
import {TestBase} from "./TestBase.sol";

contract MerkleDistributorTest is TestBase {
    MerkleDistributor private distributor;
    address private constant ALICE = address(0xA11CE);
    address private constant BOB = address(0xB0B);
    bytes32 private aliceLeaf;
    bytes32 private bobLeaf;

    function setUp() public {
        vm.deal(address(this), 10 ether);
        aliceLeaf = leaf(ALICE, 2 ether);
        bobLeaf = leaf(BOB, 3 ether);
        bytes32 root = aliceLeaf < bobLeaf
            ? keccak256(abi.encodePacked(aliceLeaf, bobLeaf))
            : keccak256(abi.encodePacked(bobLeaf, aliceLeaf));
        distributor = new MerkleDistributor{value: 5 ether}(root);
    }

    function testRejectsZeroRoot() public {
        vm.expectRevert(MerkleDistributor.InvalidRoot.selector);
        new MerkleDistributor{value: 1}(bytes32(0));
    }

    function testRejectsEmptyFunding() public {
        vm.expectRevert(MerkleDistributor.EmptyFunding.selector);
        new MerkleDistributor(aliceLeaf);
    }

    function testBothLeavesCanClaimAndOnlyOnce() public {
        vm.prank(ALICE);
        distributor.claim(2 ether, proofOf(bobLeaf), payable(ALICE));
        vm.prank(BOB);
        distributor.claim(3 ether, proofOf(aliceLeaf), payable(BOB));
        assertEq(ALICE.balance, 2 ether);
        assertEq(BOB.balance, 3 ether);
        assertEq(address(distributor).balance, 0);

        vm.prank(ALICE);
        vm.expectRevert(MerkleDistributor.AlreadyClaimed.selector);
        distributor.claim(2 ether, proofOf(bobLeaf), payable(ALICE));
    }

    function testRejectsWrongAmountCallerAndRecipient() public {
        vm.prank(ALICE);
        vm.expectRevert(MerkleDistributor.InvalidClaim.selector);
        distributor.claim(0, proofOf(bobLeaf), payable(ALICE));
        vm.prank(ALICE);
        vm.expectRevert(MerkleDistributor.InvalidClaim.selector);
        distributor.claim(2 ether, proofOf(bobLeaf), payable(address(0)));
        vm.prank(ALICE);
        vm.expectRevert(MerkleDistributor.InvalidProof.selector);
        distributor.claim(3 ether, proofOf(bobLeaf), payable(ALICE));
        vm.expectRevert(MerkleDistributor.InvalidProof.selector);
        distributor.claim(2 ether, proofOf(bobLeaf), payable(ALICE));
    }

    function testTransferFailureKeepsClaimAvailable() public {
        vm.prank(ALICE);
        vm.expectRevert(MerkleDistributor.TransferFailed.selector);
        distributor.claim(2 ether, proofOf(bobLeaf), payable(address(this)));
        assertTrue(!distributor.claimed(ALICE));
        assertEq(address(distributor).balance, 5 ether);

        vm.prank(ALICE);
        distributor.claim(2 ether, proofOf(bobLeaf), payable(BOB));
        assertEq(BOB.balance, 2 ether);
    }

    function testFuzzSingleLeaf(uint96 amount) public {
        vm.assume(amount > 0);
        vm.deal(address(this), amount);
        MerkleDistributor single = new MerkleDistributor{value: amount}(leaf(ALICE, amount));
        vm.prank(ALICE);
        single.claim(amount, new bytes32[](0), payable(ALICE));
        assertEq(ALICE.balance, amount);
        assertEq(address(single).balance, 0);
    }

    function leaf(address account, uint256 amount) private pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(account, amount))));
    }

    function proofOf(bytes32 sibling) private pure returns (bytes32[] memory proof) {
        proof = new bytes32[](1);
        proof[0] = sibling;
    }
}
