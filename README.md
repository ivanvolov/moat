# Moat

An open-source, decentralized pre-execution firewall for smart contracts. Emulates every incoming transaction before it touches your protocol and blocks exploits before they land.

[👉explore👈](https://ivanvolov.github.io/moat/)

## The Problem

Protocols get hacked. Today's response is **reactive** — firewalls scan the mempool and try to react after the attack starts. By then, funds are often already gone.

Meanwhile, teams ship faster than ever. AI-generated code, minimal audits, or no audits at all. The attack surface is growing and audit coverage isn't keeping up.

**Hypernative Firewall** helps, but it's closed-source, proprietary, and enterprise-priced. **OpenZeppelin Defender** is sunsetting (July 2026), leaving a gap in the ecosystem. There is no open-source, decentralized alternative that any team can drop into their contracts today.

## What Moat Does

Moat sits in front of your critical function calls — deposits, withdrawals, swaps, anything you choose. It emulates the state of the protocol before and after each transaction and checks it against rules defined by the protocol team.

The team knows their protocol best. If the average user yields 20% APY but one address is pulling 300%, that's a rule the team can write in one line. Simple rules + state emulation already catches the majority of exploits.

A circuit breaker for users' transactions. Open source. Decentralized. Auditable.

## How It Works

**On-chain integration.** Add a single modifier to your critical functions. Incoming transactions are routed through the Moat contract, which gates execution based on the validation layer's verdict.

**Off-chain validation.** A lightweight backend emulates the protocol state before and after the transaction, then checks it against the team's rules — value limits, yield anomalies, frequency caps, balance ratios. The protocol team defines the rules because they understand their system's invariants better than anyone.

**Decentralized operators.** The validation layer runs as an AVS on Symbiotic / EigenLayer. Not one backend, not one team — a network of operators running the same emulation and rule-checking logic. Composes with existing threat intel feeds (Forta, ChainPatrol) and premade validation templates (TVL-based, PnL-based, custom).

**Guaranteed user fallback.** If a transaction is blocked, a 30-minute timelock activates. After 30 minutes, the user can push the transaction through regardless. The protocol team can never permanently censor — but they get a 30-minute window to respond to a real incident.

**Zero-latency path.** For latency-sensitive operations, transactions can be submitted directly to the Moat watchtower off-chain (similar to Flashbots Protect) — validated and forwarded without added delay.

## Architecture

Moat is built by composing existing, audited primitives:

- **On-chain enforcement** — built on the Forta Firewall proxy (or similar primitive). Open-source, audited, in production.
- **Decentralized attestation service** — runs as an AVS on Symbiotic / EigenLayer. Operators emulate the protocol state before/after, run the team's rules, and sign attestations.
- **Rule definition** — premade templates (TVL-based, PnL-based, balance-ratio, yield-anomaly) plus a Claude Skill that compiles plain-English protocol invariants into executable rule logic. Teams describe what "normal" looks like in their own words, and the skill turns it into code.

## Why This Matters

**Shrink your attack surface.** Put Moat in front of withdraw, deposit, and other high-risk functions. Your audit budget can now focus on the parts of your protocol that can't be covered by a firewall.

**Ship faster, safer.** A new team with a limited security budget can dramatically raise their protection floor by closing off critical entry points. Not a replacement for audits — a safety net for everything audits miss.

**Open source, built from audited components.** Moat uses battle-tested building blocks — OpenZeppelin libraries, established AVS patterns, the Forta Firewall proxy. The firewall itself can be audited once and reused by every protocol that integrates it.

**Composable.** Add Moat to deposit/withdraw and other critical functions and cover ~90% of your attack surface out of the box. Layer on Hypernative, Forta, or custom detection engines later as your protocol matures.

## Implementation

See the [Integration Guide](INTEGRATION_GUIDE.md) for the full component map, transaction flow, and a walkthrough of how to put Moat in front of your own protocol.

## Support Moat on Giveth

Moat is listed as a public good on Giveth — [support development here](https://giveth.io/project/open-source-smart-contract-firewall  ).
