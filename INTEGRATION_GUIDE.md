# Integration Guide

This guide walks through the Moat system from the perspective of a protocol team that wants to put it in front of their contracts. It covers what each component does, how they fit together, and what a minimal integration looks like.

Moat is three independently-shippable pieces: an on-chain firewall contract, an off-chain validation engine, and a landing page / docs site. You can run them locally, deploy them separately, and replace any one of them without touching the others.

## Components

- [**Firewall contract**](firewall/README.md) — the on-chain enforcement layer. Queues user transactions, gates execution on watchtower approval, and guarantees a timelock fallback so the protocol team can never permanently censor a user. Handles ERC-20 token flow so targets never see approvals that outlive a single call.
- [**Validation engine**](engine/README.md) — the off-chain watchtower. Listens for `Queued` events, simulates each transaction against a fork of current chain state, runs the protocol team's rules over the pre/post state, and approves or lets the timelock expire. Rules are plain TypeScript files with a single `evaluate` function.
- [**Landing page**](app/README.md) — the public-facing site. Static, deployable to GitHub Pages, useful as a reference for the project's positioning and architecture.

## How a transaction flows through Moat

1. **User calls `submit` on the firewall** with the target contract, calldata, and optionally `(token, tokenAmount)` for ERC-20 flows. The firewall stores the call and emits `Queued`.
2. **The engine picks up the event** via its watcher, forks the chain at the current block, and simulates the call against the fork. It reads the protocol's state before and after, then runs every rule in `engine/src/rules/` against that context.
3. **If every rule passes**, the engine's watchtower key calls `approve(id)` on the firewall, which executes the call atomically (pulling tokens from the submitter, approving the target for exactly the committed amount, calling it, then resetting the allowance).
4. **If any rule fails**, the engine does nothing. After the timelock expires, the submitter can call `pushThrough(id)` themselves — the team's protection window was 30 minutes, not forever.

## Integrating with your protocol

Your contract must refuse calls from anyone except the firewall — users are required to go through it. A simple whitelist on the firewall side is not enough, because nothing stops a user from calling your contract directly and bypassing the validation layer entirely. The point of Moat is that the protection is unavoidable, and that only works if the gated contract enforces it on its own side.

In practice this means adding an `onlyFirewall` modifier to every entry point you want protected:

```solidity
modifier onlyFirewall() {
    if (msg.sender != FIREWALL) revert NotFirewall(msg.sender);
    _;
}
```

See [`firewall/test/utils/FirewallVault.sol`](firewall/test/utils/FirewallVault.sol) for a reference implementation — it's an ERC-4626 vault with `onlyFirewall` on `deposit`, `mint`, `withdraw`, and `redeem`. Admin-only functions and read-only views don't need the gate; only the user-facing state-changing calls you actually want validated.

Once your contract is gated, the workflow for the protocol team is: write rules in `engine/src/rules/` that describe what "normal" looks like, deploy the engine as your watchtower, and set the firewall's watchtower address to the engine's signing key.

## Writing rules

Rules live in [`engine/src/rules/`](engine/src/rules/) and export a single object with an `evaluate(ctx)` function. The context gives you pre/post protocol state, the submitted transaction, and external data (Chainlink prices, etc.). Return `{ pass: true }` to allow or `{ pass: false, reason }` to block.

Three rules ship as examples: `tvl-drop` (blocks calls that drain more than 5% of TVL), `single-transfer-cap` (per-user extraction ceiling), and `apy-anomaly` (catches share-price manipulation / flash-loan attacks). They're short, readable, and a good starting point for your own.

## Local development

```shell
# Firewall — compile and test the contract
cd firewall && forge build && forge test

# Engine — unit tests (fast) and end-to-end tests (spawns anvil, deploys the firewall)
cd engine && npm install && npm run test:unit && npm run test:e2e
```

The engine's e2e tests require the firewall artifacts to exist in `firewall/out/`, so run `forge build` in `firewall/` first. Anvil must be on your `PATH` — it ships with Foundry.

## Agent setup

If you're using an AI coding agent (Claude Code, Cursor, etc.) to work on this repo, see [`agent-setup/CLAUDE.md`](agent-setup/CLAUDE.md) for repo conventions, test commands, and context on how the pieces are wired together. It's aimed at giving an agent enough context to make useful changes without accidentally breaking invariants.
