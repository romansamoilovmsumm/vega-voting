// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {VVToken} from "../src/VVToken.sol";
import {VotingResultsNFT} from "../src/VotingResultsNFT.sol";
import {VegaVoting} from "../src/VegaVoting.sol";

contract Deploy is Script {
    function run() external returns (VVToken token, VotingResultsNFT nft, VegaVoting voting) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        token = new VVToken(vm.addr(deployerKey));
        nft = new VotingResultsNFT(vm.addr(deployerKey));
        voting = new VegaVoting(token, nft);

        nft.setVotingContract(address(voting));
        nft.transferOwnership(address(voting));

        vm.stopBroadcast();

        console2.log("VVToken:", address(token));
        console2.log("VotingResultsNFT:", address(nft));
        console2.log("VegaVoting:", address(voting));
    }
}
