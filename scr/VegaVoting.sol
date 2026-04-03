// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {VotingResultsNFT} from "./VotingResultsNFT.sol";

contract VegaVoting is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant MIN_LOCK_DAYS = 1;
    uint256 public constant MAX_LOCK_DAYS = 4;

    error VoteAlreadyExists(bytes32 id);
    error VoteDoesNotExist(bytes32 id);
    error VoteAlreadyFinalized(bytes32 id);
    error VoteNotFinalizable(bytes32 id);
    error InvalidDeadline();
    error InvalidThreshold();
    error InvalidLockDays();
    error InvalidAmount();
    error AlreadyVoted(bytes32 id, address voter);
    error NoVotingPower(address voter);
    error NotStakeOwner(uint256 stakeId);
    error StakeStillLocked(uint256 stakeId);
    error StakeAlreadyWithdrawn(uint256 stakeId);
    error InvalidAddress();

    struct Vote {
        bytes32 id;
        address creator;
        uint64 deadline;
        uint256 votingPowerThreshold;
        string description;
        uint256 yesPower;
        uint256 noPower;
        bool finalized;
        bool passed;
        uint256 nftTokenId;
    }

    struct StakePosition {
        address owner;
        uint256 amount;
        uint64 expiry;
        bool withdrawn;
    }

    IERC20 public immutable vvToken;
    VotingResultsNFT public immutable resultsNft;

    uint256 private _nextStakeId = 1;
    mapping(uint256 => StakePosition) public stakes;
    mapping(address => uint256[]) private _stakeIdsByOwner;
    mapping(bytes32 => Vote) private _votes;
    mapping(bytes32 => bool) private _voteExists;
    mapping(bytes32 => mapping(address => bool)) private _hasVoted;
    mapping(bytes32 => mapping(address => uint256)) private _voterPower;

    event VoteCreated(bytes32 indexed id, address indexed creator, uint64 deadline, uint256 threshold, string description);
    event VoteCast(bytes32 indexed id, address indexed voter, bool support, uint256 power);
    event VoteFinalized(bytes32 indexed id, uint256 indexed nftTokenId, bool passed, uint256 yesPower, uint256 noPower);
    event StakeCreated(address indexed user, uint256 indexed stakeId, uint256 amount, uint64 expiry, uint8 lockDays);
    event StakeWithdrawn(address indexed user, uint256 indexed stakeId, uint256 amount);

    constructor(IERC20 vvToken_, VotingResultsNFT resultsNft_) Ownable(msg.sender) {
        if (address(vvToken_) == address(0) || address(resultsNft_) == address(0)) revert InvalidAddress();
        vvToken = vvToken_;
        resultsNft = resultsNft_;
    }

    function createVote(
        bytes32 id,
        uint64 deadline,
        uint256 votingPowerThreshold,
        string calldata description
    ) external onlyOwner whenNotPaused {
        if (_voteExists[id]) revert VoteAlreadyExists(id);
        if (deadline <= block.timestamp) revert InvalidDeadline();
        if (votingPowerThreshold == 0) revert InvalidThreshold();

        _voteExists[id] = true;
        _votes[id] = Vote({
            id: id,
            creator: msg.sender,
            deadline: deadline,
            votingPowerThreshold: votingPowerThreshold,
            description: description,
            yesPower: 0,
            noPower: 0,
            finalized: false,
            passed: false,
            nftTokenId: 0
        });

        emit VoteCreated(id, msg.sender, deadline, votingPowerThreshold, description);
    }

    function getVote(bytes32 id) external view returns (Vote memory) {
        if (!_voteExists[id]) revert VoteDoesNotExist(id);
        return _votes[id];
    }

    function stake(uint256 amount, uint8 lockDays) external whenNotPaused nonReentrant returns (uint256 stakeId) {
        if (amount == 0) revert InvalidAmount();
        if (lockDays < MIN_LOCK_DAYS || lockDays > MAX_LOCK_DAYS) revert InvalidLockDays();

        vvToken.safeTransferFrom(msg.sender, address(this), amount);

        stakeId = _nextStakeId++;
        uint64 expiry = uint64(block.timestamp + uint256(lockDays) * 1 days);
        stakes[stakeId] = StakePosition({owner: msg.sender, amount: amount, expiry: expiry, withdrawn: false});
        _stakeIdsByOwner[msg.sender].push(stakeId);

        emit StakeCreated(msg.sender, stakeId, amount, expiry, lockDays);
    }

    function withdraw(uint256 stakeId) external nonReentrant {
        StakePosition storage stakePosition = stakes[stakeId];
        if (stakePosition.owner != msg.sender) revert NotStakeOwner(stakeId);
        if (stakePosition.withdrawn) revert StakeAlreadyWithdrawn(stakeId);
        if (block.timestamp < stakePosition.expiry) revert StakeStillLocked(stakeId);

        stakePosition.withdrawn = true;
        vvToken.safeTransfer(msg.sender, stakePosition.amount);

        emit StakeWithdrawn(msg.sender, stakeId, stakePosition.amount);
    }

    function castVote(bytes32 id, bool support) external whenNotPaused nonReentrant {
        Vote storage vote = _votes[id];
        if (!_voteExists[id]) revert VoteDoesNotExist(id);
        if (vote.finalized) revert VoteAlreadyFinalized(id);
        if (block.timestamp >= vote.deadline) revert VoteNotFinalizable(id);
        if (_hasVoted[id][msg.sender]) revert AlreadyVoted(id, msg.sender);

        uint256 power = currentVotingPower(msg.sender);
        if (power == 0) revert NoVotingPower(msg.sender);

        _hasVoted[id][msg.sender] = true;
        _voterPower[id][msg.sender] = power;

        if (support) {
            vote.yesPower += power;
        } else {
            vote.noPower += power;
        }

        emit VoteCast(id, msg.sender, support, power);
    }

    function currentVotingPower(address account) public view returns (uint256 power) {
        uint256[] storage stakeIds = _stakeIdsByOwner[account];
        for (uint256 i = 0; i < stakeIds.length; i++) {
            StakePosition storage stakePosition = stakes[stakeIds[i]];
            if (stakePosition.withdrawn || stakePosition.owner != account || block.timestamp >= stakePosition.expiry) {
                continue;
            }
            power += _stakePower(stakePosition);
        }
    }

    function voterPower(bytes32 id, address voter) external view returns (uint256) {
        return _voterPower[id][voter];
    }

    function hasVoted(bytes32 id, address voter) external view returns (bool) {
        return _hasVoted[id][voter];
    }

    function canFinalize(bytes32 id) public view returns (bool) {
        if (!_voteExists[id]) return false;
        Vote storage vote = _votes[id];
        if (vote.finalized) return false;
        return block.timestamp >= vote.deadline || vote.yesPower >= vote.votingPowerThreshold;
    }

    function finalizeVote(bytes32 id) external whenNotPaused nonReentrant returns (uint256 nftTokenId) {
        Vote storage vote = _votes[id];
        if (!_voteExists[id]) revert VoteDoesNotExist(id);
        if (vote.finalized) revert VoteAlreadyFinalized(id);
        if (!(block.timestamp >= vote.deadline || vote.yesPower >= vote.votingPowerThreshold)) {
            revert VoteNotFinalizable(id);
        }

        vote.finalized = true;
        vote.passed = vote.yesPower >= vote.votingPowerThreshold;
        vote.nftTokenId = resultsNft.mintReceipt(
            vote.creator,
            vote.id,
            vote.creator,
            vote.passed,
            vote.yesPower,
            vote.noPower,
            uint64(block.timestamp),
            vote.description
        );
        nftTokenId = vote.nftTokenId;

        emit VoteFinalized(id, nftTokenId, vote.passed, vote.yesPower, vote.noPower);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function rescueERC20(address token, address to, uint256 amount) external onlyOwner nonReentrant {
        if (token == address(vvToken)) revert InvalidAddress();
        IERC20(token).safeTransfer(to, amount);
    }

    function _stakePower(StakePosition storage stakePosition) internal view returns (uint256) {
        if (block.timestamp >= stakePosition.expiry) return 0;
        uint256 remainingSeconds = uint256(stakePosition.expiry - uint64(block.timestamp));
        uint256 remainingDays = (remainingSeconds + 1 days - 1) / 1 days;
        if (remainingDays == 0) remainingDays = 1;
        return stakePosition.amount * remainingDays * remainingDays;
    }
}
