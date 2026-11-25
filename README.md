# Merkle Distributor

A prefunded ETH distribution where recipients prove their allocations against a Merkle root.

## How it works

1. Build a tree off-chain with leaves `keccak256(bytes.concat(keccak256(abi.encode(account, amount))))`. Hash sorted sibling pairs with `keccak256(abi.encodePacked(lower, higher))`.
2. Deploy with the root and enough ETH to fund the full distribution.
3. A recipient calls `claim(amount, proof, recipient)` from the address in the tree and may direct payment to a receiving address of their choice.

The tree must contain one allocation per address. The root is immutable, there is no claim deadline, and unclaimed or surplus ETH stays in the contract.

## Build and test

Install [Foundry](https://getfoundry.sh/) and run these commands from this directory. Forge selects Solidity 0.8.36 from `foundry.toml`. The project has no third-party Solidity dependencies.

```bash
forge build
forge test -vv
forge coverage --exclude-tests
```

## Local deployment

Start a fresh `anvil` node in a separate terminal. Deploy with the first unlocked account on that local node.

```bash
export RPC_URL=http://127.0.0.1:8545
export ANVIL_ACCOUNT=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
forge create src/MerkleDistributor.sol:MerkleDistributor --rpc-url "$RPC_URL" --from "$ANVIL_ACCOUNT" --unlocked --broadcast --value 1ether --constructor-args "$(cast keccak "$(cast keccak "$(cast abi-encode 'f(address,uint256)' "$ANVIL_ACCOUNT" 1000000000000000000)")")"
```

## Local example

Set `CONTRACT` to the address printed by `forge create` and keep using the same terminal. The deployment example uses a single leaf, so the proof is an empty array.

```bash
export ETH_RPC_URL="$RPC_URL"
CONTRACT=0x... # Replace with your deployed address.
cast send "$CONTRACT" 'claim(uint256,bytes32[],address)' 1000000000000000000 '[]' "$ANVIL_ACCOUNT" --from "$ANVIL_ACCOUNT" --unlocked
cast call "$CONTRACT" 'claimed(address)(bool)' "$ANVIL_ACCOUNT"
```

## Test cases

Foundry reports 6 passing tests and 100% coverage on contract lines, statements, branches and functions.

- Both sibling orderings and a single-leaf proof.
- Invalid allocations, duplicate claims and conditionally rejecting recipients.
- Fuzzed single-leaf allocations with balance checks.
