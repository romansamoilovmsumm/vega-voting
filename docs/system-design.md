# Vega Voting Protocol - System Design

## Components

### 1. VVToken
- ERC20 token used for staking and voting power.
- Minted by the token owner for test/deployment flows.

### 2. VegaVoting
- Ownable admin contract.
- Creates votes with unique `bytes32` IDs.
- Accepts user stakes locked for 1-4 days.
- Calculates voting power from active stakes.
- Records yes/no votes.
- Finalizes a vote when the deadline passes or the yes-side threshold is reached.
- Mints the receipt NFT after finalization.
- Supports pause/unpause for emergency response.

### 3. VotingResultsNFT
- ERC721 receipt NFT.
- Stores the final result data on-chain.
- Token metadata includes the vote id, result, power totals, and finalization time.

## Trust model

- Admin can create votes and pause the system.
- Anyone can finalize a vote once it becomes eligible.
- No off-chain oracle is required.
- NFT minting is restricted to the voting contract.

## User flow

1. User receives VV tokens.
2. User approves `VegaVoting`.
3. User stakes tokens for 1-4 days.
4. User casts a yes/no vote.
5. Vote finalizes after deadline or threshold.
6. Receipt NFT is minted to the vote creator.

## Emergency controls

- `pause()` blocks vote creation, staking, voting, and withdrawals.
- `finalizeVote()` remains available so eligible votes can still be closed.
- `rescueERC20()` can recover stray tokens except VV.

## Notes

The assignment PDF renders the voting-power formula with slightly distorted notation. The implementation uses a deterministic interpretation that matches the described behavior: current voting power grows with stake size and decreases with the remaining lock time.
