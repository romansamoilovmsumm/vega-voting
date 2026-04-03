// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {VVToken} from "../src/VVToken.sol";
import {VotingResultsNFT} from "../src/VotingResultsNFT.sol";
import {VegaVoting} from "../src/VegaVoting.sol";

contract DemoSetup is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        uint256 voter1Key = vm.envUint("VOTER1_PRIVATE_KEY");
        uint256 voter2Key = vm.envUint("VOTER2_PRIVATE_KEY");

        address deployer = vm.addr(deployerKey);
        address voter1 = vm.addr(voter1Key);
        address voter2 = vm.addr(voter2Key);

        vm.startBroadcast(deployerKey);
        VVToken token = new VVToken(deployer);
        VotingResultsNFT nft = new VotingResultsNFT(deployer);
        VegaVoting voting = new VegaVoting(token, nft);
        nft.setVotingContract(address(voting));
        nft.transferOwnership(address(voting));

        token.mint(voter1, 1_000 ether);
        token.mint(voter2, 1_000 ether);

        bytes32 voteId = keccak256("vega-voting-demo-1");
        voting.createVote(
            voteId,
            uint64(block.timestamp + 3 days),
            20_000 ether,
            "Should VegaVoting launch on Sepolia?"
        );
        vm.stopBroadcast();

        vm.startBroadcast(voter1Key);
        token.approve(address(voting), type(uint256).max);
        voting.stake(1_000 ether, 4);
        voting.castVote(voteId, true);
        vm.stopBroadcast();

        vm.startBroadcast(voter2Key);
        token.approve(address(voting), type(uint256).max);
        voting.stake(1_000 ether, 4);
        voting.castVote(voteId, true);
        vm.stopBroadcast();

        vm.startBroadcast(deployerKey);
        uint256 nftTokenId = voting.finalizeVote(voteId);
        vm.stopBroadcast();

        console2.log("Vote ID:", voteId);
        console2.log("NFT token ID:", nftTokenId);
        console2.log("Token:", address(token));
        console2.log("NFT:", address(nft));
        console2.log("Voting:", address(voting));
        console2.log("Deployer:", deployer);
        console2.log("Voter1:", voter1);
        console2.log("Voter2:", voter2);
    }
}
