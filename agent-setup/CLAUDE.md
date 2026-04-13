# CLAUDE.md

Context for AI coding agents working on this repository. Keep this file short and useful — prefer pointers to source over duplicating code.

## Repo layout

- `firewall/` — Foundry project. The on-chain `MoatFirewall` contract, its tests, and a deploy script. Run `forge test` here.
- `engine/` — TypeScript project using viem. Off-chain watchtower: watches firewall events, simulates queued transactions on an anvil fork, runs rules, approves valid ones. Run `npm run test:unit` (fast, pure rule logic) and `npm run test:e2e` (spawns anvil, deploys the firewall artifact).
- `app/` — static landing page. Not load-bearing for the protocol.
- `INTEGRATION_GUIDE.md` — human-facing integration guide. Read this first to understand how the pieces fit.

## Project conventions

- **Solidity**: custom errors, not `require` strings. `prettier-plugin-solidity` formats with `make fmt` or `npm run fmt` inside `firewall/`. Tests live under `firewall/test/` split by concern (`Submit.t.sol`, `Approve.t.sol`, `PushThrough.t.sol`, `Admin.t.sol`, `Integration.t.sol`, `Fuzz.t.sol`).
- **TypeScript**: ESM, `"type": "module"`. Imports use `.js` extensions even for `.ts` source — required by Node's ESM resolver. Engine uses viem, not ethers.
- **Rules**: each rule is a single file in `engine/src/rules/` exporting an object with `id`, `description`, and `async evaluate(ctx)`. Constants go at the top of the file. Keep them short — a rule that doesn't fit on one screen is probably two rules.

## Invariants to protect

- The firewall must never let a non-submitter call `pushThrough`. Only the submitter has the right to bypass the watchtower after the timelock.
- The firewall must reset ERC-20 allowances to zero after each execution. No leftover approval on the firewall is allowed under any code path.
- `Rejected` status was deliberately removed. Non-approval within the timelock *is* the rejection. Don't re-add `reject()` without discussing it.
- The `Transaction` ID is `keccak256(abi.encode(submitter, target, data, block.timestamp))`. Duplicate IDs in the same block revert — this is intentional and cheaper than a nonce.

## Running tests

```shell
# Contract tests
cd firewall && forge test

# Engine tests — unit (rule logic, no network)
cd engine && npm run test:unit

# Engine tests — end-to-end (spawns anvil, deploys firewall from artifacts)
cd engine && npm run test:e2e
```

The engine's e2e suite loads compiled artifacts from `firewall/out/`. If you've edited the contract, run `forge build` in `firewall/` before `npm run test:e2e` or you'll test the old bytecode.

## Things that will trip you up

- **`tx` is a Solidity builtin.** Don't name local variables `tx` in storage pointers — use `txn`. The compiler warns and the tests will catch it.
- **ERC-4626 `_withdraw` checks share allowance** from owner to caller by default. The firewall is the caller but holds no shares. `FirewallVault` overrides `_withdraw` to skip this check — the firewall already enforces submitter-only withdrawal at its own layer.
- **Users approve the firewall, not the target.** The firewall pulls tokens on execution, approves the target for the exact committed amount, calls it, then resets. Targets that try to pull more than the committed amount will fail.
- **Engine imports use `.js` extensions** even for `.ts` source files. This is required by Node's ESM resolver with `"type": "module"`. Don't "fix" them.

## What to do when you're stuck

Read `INTEGRATION_GUIDE.md` and the component READMEs (`firewall/README.md`, `engine/README.md`) before asking the user. The tests are the best documentation of intended behavior — they're small, readable, and exercise every path.

## Status

This file is a work in progress. Add to it when you learn something non-obvious about the repo that would have saved you time earlier. Don't duplicate what's already in the READMEs or source comments.
