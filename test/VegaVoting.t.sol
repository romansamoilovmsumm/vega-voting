// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {VVToken} from "../src/VVToken.sol";
import {VotingResultsNFT} from "../src/VotingResultsNFT.sol";
import {VegaVoting} from "../src/VegaVoting.sol";

contract VegaVotingTest is Test {
    VVToken token;
    VotingResultsNFT nft;
    VegaVoting voting;

    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    bytes32 voteId;

    function setUp() public {
        token = new VVToken(address(this));
        nft = new VotingResultsNFT(address(this));
        voting = new VegaVoting(token, nft);
        nft.setVotingContract(address(voting));
        nft.transferOwnership(address(voting));

        token.mint(alice, 1_000 ether);
        token.mint(bob, 1_000 ether);

        voteId = keccak256("test-vote-1");
        voting.createVote(voteId, uint64(block.timestamp + 2 days), 20_000 ether, "Test vote");
    }

    function testOnlyOwnerCanCreateVote() public {
        vm.prank(alice);
        vm.expectRevert();
        voting.createVote(keccak256("another"), uint64(block.timestamp + 1 days), 1 ether, "Nope");
    }

    function testVotingFlowAndNFTMint() public {
        vm.startPrank(alice);
        token.approve(address(voting), type(uint256).max);
        voting.stake(1_000 ether, 4);
        voting.castVote(voteId, true);
        vm.stopPrank();

        vm.startPrank(bob);
        token.approve(address(voting), type(uint256).max);
        voting.stake(1_000 ether, 4);
        voting.castVote(voteId, true);
        vm.stopPrank();

        assertTrue(voting.canFinalize(voteId));

        uint256 nftTokenId = voting.finalizeVote(voteId);
        assertEq(nft.ownerOf(nftTokenId), address(this));

        (bytes32 storedId, address creator, bool passed, uint256 yesPower, uint256 noPower, uint64 finalizedAt,) = nft.receipt(nftTokenId);
        assertEq(storedId, voteId);
        assertEq(creator, address(this));
        assertTrue(passed);
        assertGt(yesPower, 0);
        assertEq(noPower, 0);
        assertEq(finalizedAt, uint64(block.timestamp));
    }

    function testPauseBlocksStakeAndVoting() public {
        voting.pause();

        vm.startPrank(alice);
        token.approve(address(voting), type(uint256).max);
        vm.expectRevert();
        voting.stake(1 ether, 1);
        vm.stopPrank();

        vm.expectRevert();
        voting.createVote(keccak256("paused"), uint64(block.timestamp + 1 days), 1 ether, "Paused");
    }

    function testWithdrawAfterExpiry() public {
        vm.startPrank(alice);
        token.approve(address(voting), type(uint256).max);
        uint256 stakeId = voting.stake(10 ether, 1);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days + 1);

        uint256 balanceBefore = token.balanceOf(alice);
        vm.prank(alice);
        voting.withdraw(stakeId);
        assertEq(token.balanceOf(alice), balanceBefore + 10 ether);
    }

    function testVotingPowerDecaysOverTime() public {
        vm.startPrank(alice);
        token.approve(address(voting), type(uint256).max);
        voting.stake(1 ether, 4);
        vm.stopPrank();

        uint256 powerAtStart = voting.currentVotingPower(alice);
        vm.warp(block.timestamp + 2 days);
        uint256 powerLater = voting.currentVotingPower(alice);

        assertGt(powerAtStart, powerLater);
        assertGt(powerLater, 0);
    }
}
