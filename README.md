> **Heads-up — this repository is work-in-progress.**
>
> The public code here lags the current internal work by roughly **two months**. The architecture, rule shapes, and product framing have evolved meaningfully since the last push to `main`. Please wait for the upcoming release before forking or integrating.

---

# Moat

An open-source, decentralized pre-execution firewall for smart contracts. Emulates every incoming transaction before it touches your protocol and blocks exploits before they land — checked against the simple invariants the team already wrote.

[👉explore👈](https://ivanvolov.github.io/moat/)

## The Problem

Protocols get hacked. Today's response is **reactive** — firewalls scan the mempool and try to react after the attack starts. By then, funds are often already gone.

Meanwhile, teams ship faster than ever. Lean teams in 2026 increasingly ship with LLM-assisted audits and no firewall budget — exactly the buyer who has nothing to drop in today. The attack surface is growing and audit coverage isn't keeping up.
- **Hypernative Firewall** helps, but it's closed-source, proprietary, and enterprise-priced — unavailable to most early teams. 
- **Forta Firewall** and **Ironblocks** ship a custom-rule surface, but the products are built around vendor-managed detection (AI Attesters and compliance filters at Forta, Approved Patterns at Ironblocks) — designed for L2s and protocols subscribing to a catalog, not for a lean team running its own simple rules.
- **There is no permissively-licensed firewall built around the team's own simple rules they can easily install on day one.**

## Architecture

Moat sits in front of your critical function calls — deposits, withdrawals, swaps, anything you choose. A circuit breaker for users' transactions. Open source. Auditable.

It operates at the intersection of a thin on-chain enforcement layer and an off-chain validator:

- **The on-chain layer is the modifier and the force-through.** A single modifier added to the functions you choose to protect — `withdraw`, `deposit`, anything critical. Routes the call through the firewall, blocks it on the validator's verdict, but still opens a 30-minute force-through timelock. That is the entire on-chain surface — every rule runs in the off-chain validator below.

- **The protocol team writes the rules.** Two shapes, both natural to the engineers who designed the protocol. *Pre/post-state invariants* — the same Foundry / Echidna predicates already in your test suite: constant-product, share-price bounds, reserve ratios, solvency. *Statistical bounds* — limits on aggregate behavior proven via zk-coprocessor (Brevis): per-user yield caps, profit thresholds, TVL anomaly bands. The class of rules that catches the *one address suddenly earning 1,000,000% APY while every other LP earns 10%* exit, without any black-box ML. The CTO authors them, ships them in the repo, and can read them out loud to an LP.

- **Self-hosted backend at v1.** The rules that don't fit on-chain — the full invariant set under state emulation — run on a backend that the team hosts themselves. Early-stage protocols already retain a lot of operational control (admin keys, upgrade powers, the ability to pull liquidity), so a team-hosted validator does not move the centralization needle for v1. The on-chain force-through window keeps the user from ever being permanently censored, regardless.

- **Moving to an AVS.** As the protocol decentralizes and TVL grows, the validator moves to an EigenLayer / Symbiotic AVS. A set of independent operators runs the same emulation + predicate logic, BLS-aggregates the verdicts, and the team is no longer a trusted operator. This is what makes the firewall credible to LPs at the mature stage.

- **Users are protected from both attackers and censorship.** Every blocked transaction triggers a 30-minute timelock. After 30 minutes, the user can always push through.

## Why This Matters

**Shrink your attack surface.** Put Moat in front of withdraw, deposit, and other high-risk functions. Your audit budget can now focus on the parts of your protocol that can't be covered by a firewall.

**Ship faster, safer.** A new team with a limited security budget can dramatically raise their protection floor by closing off critical entry points. Not a replacement for audits — a safety net for everything audits miss.

**Open source, built from audited components.** Moat uses battle-tested building blocks — OpenZeppelin libraries, established AVS patterns. The primitive itself is audited — integrators review their own hookup, which is minimal.

**Composable.** Moat is the floor, not the ceiling. A team integrates it on day one and keeps it. As the protocol matures and TVL grows, enterprise tooling layers on top — Hypernative's threat intel, Forta's attester network, and custom monitoring. Moat persists underneath as the place where the protocol-specific, non-outsourceable rules live: the invariants only the team can write.

## Implementation

See the [Integration Guide](INTEGRATION_GUIDE.md) for the full component map, transaction flow, and a walkthrough of how to put Moat in front of your own protocol.

## Support Moat on Giveth

Moat is listed as a public good on Giveth — [support development here](https://giveth.io/project/open-source-smart-contract-firewall).
