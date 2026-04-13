# Moat Firewall

On-chain component of [Moat](../README.md). A Solidity contract that queues transactions for watchtower review and guarantees a user-side timelock fallback.

## What it does

`MoatFirewall` sits in front of a protocol's critical function calls. Submitted transactions are held until:

- the **watchtower** approves and executes them, or
- the **timelock** expires and the original submitter pushes them through themselves.

For ERC-20 flows, the submitter commits `(token, tokenAmount)` at submission time. On execution the firewall pulls exactly that amount from the submitter, approves the target, calls it, then resets the allowance to zero — so no leftover approval ever sits on the firewall.

See [`src/MoatFirewall.sol`](src/MoatFirewall.sol) for the contract.

## Layout

```
src/
  MoatFirewall.sol       — the firewall contract
test/
  Base.t.sol             — shared setup, actors, helpers
  Submit.t.sol           — submit() validation and storage
  Approve.t.sol          — watchtower approval path
  PushThrough.t.sol      — timelock fallback path
  Admin.t.sol            — whitelist and role management
  Integration.t.sol      — end-to-end flows against an ERC-4626 vault
  Fuzz.t.sol             — fuzz tests for values, timelock, token flow
  utils/
    ERC20Mock.sol        — freely mintable ERC-20 for tests
    MockTarget.sol       — call recorder with configurable revert + token pull
    FirewallVault.sol    — ERC-4626 vault gated behind the firewall
```

## Build

```shell
forge build
```

## Test

```shell
forge test          # run the full suite
forge test -vv      # with stack traces on failures
forge coverage      # line/branch coverage report
```

## Format

The repository uses `prettier` with `prettier-plugin-solidity`. Install once, then:

```shell
npm install
npm run fmt         # or: make fmt
```

Config lives in [`.prettierrc`](.prettierrc).

## Deploy

[`script/Deploy.s.sol`](script/Deploy.s.sol) deploys `MoatFirewall` with the constructor arguments read from environment variables.

Required env vars:

- `ADMIN` — address allowed to manage the whitelist and roles
- `WATCHTOWER` — address allowed to approve pending transactions
- `TIMELOCK_DURATION` — seconds after which the submitter can `pushThrough`

Run:

```shell
ADMIN=0x... \
WATCHTOWER=0x... \
TIMELOCK_DURATION=3600 \
forge script script/Deploy.s.sol:Deploy \
  --rpc-url <rpc_url> \
  --private-key <key> \
  --broadcast \
  --verify
```

After deployment, whitelist each target contract with `allow(address)` from the admin account before users can submit transactions against it.
