# Vega Voting Protocol

Smart-contract homework implementation for a VV-based voting system.

## What is included

- `VVToken.sol` - ERC20 token for VegaVoting (VV)
- `VegaVoting.sol` - staking, voting, finalization, pause controls
- `VotingResultsNFT.sol` - ERC721 receipt NFT minted when a vote is finalized
- `test/VegaVoting.t.sol` - Foundry tests
- `script/Deploy.s.sol` - deployment script
- `script/DemoSetup.s.sol` - deploys and runs one demo vote with two addresses

## Design notes

The PDF's rendered formula is slightly distorted. I implemented the intended interpretation as:

`votingPower = amount * remainingDays^2`

with `remainingDays` capped by the chosen 1-4 day lock window. That keeps voting power aligned with the assignment's stated dependence on both amount and remaining lock duration.

Finalization is permissionless once either:

- the deadline has passed, or
- `yesPower >= votingPowerThreshold`

No extra off-chain signer is required.

## Deployment

```bash
forge install OpenZeppelin/openzeppelin-contracts --no-commit
forge install foundry-rs/forge-std --no-commit
forge build
```

Set environment variables:

```bash
export PRIVATE_KEY=...
export VOTER1_PRIVATE_KEY=...
export VOTER2_PRIVATE_KEY=...
export RPC_URL=https://sepolia.infura.io/v3/...
```

Deploy:

```bash
forge script script/Deploy.s.sol:Deploy --rpc-url $RPC_URL --broadcast
```

Run the full demo setup:

```bash
forge script script/DemoSetup.s.sol:DemoSetup --rpc-url $RPC_URL --broadcast
```

## Contract flow

1. Deploy VV, NFT, and voting contracts.
2. Set the NFT contract's `votingContract` to `VegaVoting`.
3. Transfer NFT ownership to `VegaVoting` so it can mint receipts.
4. Mint VV to two voters.
5. Voters approve, stake, and vote.
6. Anyone finalizes once the vote is eligible.
7. The receipt NFT is minted to the vote creator.
