# Moat Engine

Off-chain transaction emulation and rule evaluation engine for the MoatFirewall contract.

## How it works

1. **Watch** — subscribes to `Queued` events from the firewall contract.
2. **Emulate** — forks the chain at the current block (via Anvil), replays the transaction, and captures a `ProtocolState` snapshot before and after.
3. **Evaluate** — runs every rule in `src/rules/` concurrently against the state snapshots and oracle prices.
4. **Verdict** — calls `approve(id)` on the firewall if all rules pass. If any rule blocks the tx, the engine withholds approval and the transaction remains `Pending` until the timelock expires, at which point the original submitter can call `pushThrough`.

The firewall has no `reject` function — blocking = not approving. Users are never permanently locked out.

## Setup

```bash
cp .env.example .env
# fill in RPC_URL, FIREWALL_ADDRESS, WATCHTOWER_PRIVATE_KEY, …

npm install
npm run dev      # development (tsx watch)
npm run build && npm start   # production
```

Requires **Anvil** on `PATH` (install via [Foundry](https://getfoundry.sh/)) when `EMULATOR_BACKEND=anvil`.

## Writing rules

Each rule is a TypeScript file in `src/rules/` that exports a default object implementing the `Rule` interface:

```ts
import type { Rule, RuleContext, RuleResult } from "../types.js";

const myRule: Rule = {
  id: "my-rule",                        // unique, machine-readable
  description: "One-line description",  // shown at startup

  async evaluate(ctx: RuleContext): Promise<RuleResult> {
    const { tx, stateBefore, stateAfter, delta, external } = ctx;
    // ... your logic ...
    return { pass: true, reason: "all good" };
    // or:
    return { pass: false, reason: "something looks wrong: ..." };
  },
};

export default myRule;
```

Then add it to `src/rules/_registry.ts`:

```ts
import myRule from "./my-rule.js";
const ALL_RULES: Rule[] = [ ..., myRule ];
```

### RuleContext reference

| Field | Type | Description |
|---|---|---|
| `tx` | `QueuedTransaction` | Raw transaction metadata (submitter, target, value, calldata, …) |
| `stateBefore` | `ProtocolState` | Protocol state before the simulated tx |
| `stateAfter` | `ProtocolState` | Protocol state after the simulated tx |
| `delta` | `StateDelta` | `stateAfter - stateBefore` for each field |
| `external.prices` | `Record<string, OraclePrice>` | Chainlink feed prices keyed by label (e.g. `ETH_USD`) |

### ProtocolState fields

All values are `bigint` in their native decimal precision (18 decimals for ETH-equivalent amounts, 8 decimals for Chainlink prices).

| Field | Description |
|---|---|
| `tvl` | Total value locked (`totalAssets()` for ERC-4626) |
| `sharePrice` | Exchange rate: assets per 1e18 shares (`convertToAssets(1e18)`) |
| `totalShares` | Total shares outstanding |
| `contractBalance` | Native token balance of the target contract |
| `userShares` | Submitter's share balance |
| `userBalance` | Submitter's native token balance |
| `extra` | Arbitrary key-value bag — populate via custom state readers |

### Bundled rules

| Rule | What it catches |
|---|---|
| `apy-anomaly` | Share-price inflation in a single block (flash loan + donation attacks) |
| `tvl-drop` | Protocol-wide drain exceeding a % cap in one call |
| `single-transfer-cap` | Single user extracting more than a % of TVL or an absolute ceiling |

### Disabling a rule

Prefix the file with `_` (e.g. `_apy-anomaly.ts`) **and** remove it from `_registry.ts`.

## Emulator backends

| Backend | `EMULATOR_BACKEND` | Requirements |
|---|---|---|
| Anvil (default) | `anvil` | `anvil` on PATH |
| Tenderly | `tenderly` | `TENDERLY_ACCOUNT`, `TENDERLY_PROJECT`, `TENDERLY_ACCESS_KEY` |

## Fail-open guarantee

- A rule that throws → treated as **PASS**.
- A rule that times out (`EVAL_TIMEOUT_MS`) → treated as **PASS**.
- An engine crash → transaction stays `Pending` and the 30-minute timelock kicks in.

Users can always push their transaction through after the timelock expires.
