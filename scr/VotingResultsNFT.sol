// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract VotingResultsNFT is ERC721, Ownable {
    using Strings for uint256;

    struct ReceiptData {
        bytes32 voteId;
        address creator;
        bool passed;
        uint256 yesPower;
        uint256 noPower;
        uint64 finalizedAt;
        string description;
    }

    error NotVotingContract();
    error VotingContractNotSet();
    error InvalidAddress();

    address public votingContract;
    uint256 private _nextTokenId = 1;
    mapping(uint256 => ReceiptData) private _receipts;

    constructor(address initialOwner) ERC721("VegaVoting Results", "VVR") Ownable(initialOwner) {}

    modifier onlyVotingContract() {
        if (msg.sender != votingContract) revert NotVotingContract();
        _;
    }

    function setVotingContract(address votingContract_) external onlyOwner {
        if (votingContract_ == address(0)) revert InvalidAddress();
        votingContract = votingContract_;
    }

    function mintReceipt(
        address to,
        bytes32 voteId,
        address creator,
        bool passed,
        uint256 yesPower,
        uint256 noPower,
        uint64 finalizedAt,
        string calldata description
    ) external onlyVotingContract returns (uint256 tokenId) {
        if (votingContract == address(0)) revert VotingContractNotSet();
        tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _receipts[tokenId] = ReceiptData({
            voteId: voteId,
            creator: creator,
            passed: passed,
            yesPower: yesPower,
            noPower: noPower,
            finalizedAt: finalizedAt,
            description: description
        });
    }

    function receipt(uint256 tokenId) external view returns (ReceiptData memory) {
        _requireOwned(tokenId);
        return _receipts[tokenId];
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        ReceiptData memory r = _receipts[tokenId];

        string memory status = r.passed ? "PASSED" : "FAILED";
        string memory svg = string(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" width="900" height="520" viewBox="0 0 900 520">',
                '<rect width="100%" height="100%" fill="white"/>',
                '<text x="50" y="70" font-size="34" font-family="Arial" font-weight="700">VegaVoting Result</text>',
                '<text x="50" y="120" font-size="22" font-family="Arial">Vote ID: ',
                _bytes32ToHex(r.voteId),
                '</text>',
                '<text x="50" y="160" font-size="22" font-family="Arial">Status: ',
                status,
                '</text>',
                '<text x="50" y="200" font-size="22" font-family="Arial">Yes Power: ',
                r.yesPower.toString(),
                '</text>',
                '<text x="50" y="240" font-size="22" font-family="Arial">No Power: ',
                r.noPower.toString(),
                '</text>',
                '<text x="50" y="280" font-size="22" font-family="Arial">Finalized At: ',
                uint256(r.finalizedAt).toString(),
                '</text>',
                '<text x="50" y="340" font-size="18" font-family="Arial">',
                _escapeXML(r.description),
                '</text>',
                '</svg>'
            )
        );

        bytes memory json = abi.encodePacked(
            '{',
            '"name":"VegaVoting Result #',
            tokenId.toString(),
            '",',
            '"description":"On-chain voting receipt NFT.",',
            '"attributes":[',
                '{"trait_type":"voteId","value":"',
                _bytes32ToHex(r.voteId),
                '"},',
                '{"trait_type":"status","value":"',
                status,
                '"},',
                '{"trait_type":"yesPower","value":"',
                r.yesPower.toString(),
                '"},',
                '{"trait_type":"noPower","value":"',
                r.noPower.toString(),
                '"}',
            '],',
            '"image":"data:image/svg+xml;base64,',
            Base64.encode(bytes(svg)),
            '"}'
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(json)));
    }

    function _bytes32ToHex(bytes32 value) internal pure returns (string memory) {
        return string(abi.encodePacked("0x", _toHex(uint256(value), 64)));
    }

    function _toHex(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(length);
        for (uint256 i = length; i > 0; --i) {
            uint256 nibble = value & 0xf;
            buffer[i - 1] = bytes1(uint8(nibble + (nibble < 10 ? 48 : 87)));
            value >>= 4;
        }
        return string(buffer);
    }

    function _escapeXML(string memory input) internal pure returns (string memory) {
        bytes memory b = bytes(input);
        bytes memory out = new bytes(b.length * 6);
        uint256 j = 0;
        for (uint256 i = 0; i < b.length; i++) {
            bytes1 c = b[i];
            if (c == 0x3c) {
                out[j++] = 0x26;
                out[j++] = 0x6c;
                out[j++] = 0x74;
                out[j++] = 0x3b;
            } else if (c == 0x3e) {
                out[j++] = 0x26;
                out[j++] = 0x67;
                out[j++] = 0x74;
                out[j++] = 0x3b;
            } else if (c == 0x26) {
                out[j++] = 0x26;
                out[j++] = 0x61;
                out[j++] = 0x6d;
                out[j++] = 0x70;
                out[j++] = 0x3b;
            } else if (c == 0x22) {
                out[j++] = 0x26;
                out[j++] = 0x71;
                out[j++] = 0x75;
                out[j++] = 0x6f;
                out[j++] = 0x74;
                out[j++] = 0x3b;
            } else {
                out[j++] = c;
            }
        }
        bytes memory trimmed = new bytes(j);
        for (uint256 k = 0; k < j; k++) trimmed[k] = out[k];
        return string(trimmed);
    }
}
