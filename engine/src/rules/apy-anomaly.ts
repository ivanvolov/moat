// Detects share-price inflation in a single block (flash loan + donation attacks).
// Implied APY is estimated from the per-block share-price delta, then annualised.

import type { Rule, RuleContext, RuleResult } from "../types.js";

const MAX_APY_BPS       = 5_000n;  // 50% annualised — hard ceiling
const CHAINLINK_PREMIUM = 10n;     // reject if implied APY > N× ETH oracle baseline; 0n = disabled
const SECONDS_PER_YEAR  = 31_536_000n;
const AVG_BLOCK_SECONDS = 12n;
const BPS               = 10_000n;
const CHAINLINK_DEC     = BigInt(1e8);

const rule: Rule = {
  id:          "apy-anomaly",
  description: "Blocks transactions that imply an abnormally high per-block yield (share-price manipulation).",

  async evaluate({ stateBefore, stateAfter, external }: RuleContext): Promise<RuleResult> {
    if (stateBefore.sharePrice === 0n)
      return { pass: true, reason: "no share price before tx" };

    const delta = stateAfter.sharePrice - stateBefore.sharePrice;
    if (delta <= 0n)
      return { pass: true, reason: "share price unchanged or decreased" };

    // implied_apy_bps = (delta / before) * (SECONDS_PER_YEAR / AVG_BLOCK) * BPS
    const impliedBps = (delta * SECONDS_PER_YEAR * BPS) / (stateBefore.sharePrice * AVG_BLOCK_SECONDS);

    if (impliedBps > MAX_APY_BPS)
      return { pass: false, reason: `implied APY ${bps(impliedBps)} exceeds ceiling ${bps(MAX_APY_BPS)}` };

    if (CHAINLINK_PREMIUM > 0n) {
      const feed = external.prices["ETH_USD"];
      if (feed) {
        const baselineBps = (feed.price * BPS) / (CHAINLINK_DEC * 100n);
        const ceiling     = baselineBps * CHAINLINK_PREMIUM;
        if (ceiling > 0n && impliedBps > ceiling)
          return { pass: false, reason: `implied APY ${bps(impliedBps)} is >${CHAINLINK_PREMIUM}× oracle baseline ${bps(baselineBps)}` };
      }
    }

    return { pass: true, reason: `implied APY ${bps(impliedBps)} within bounds` };
  },
};

function bps(v: bigint): string { return `${(Number(v) / 100).toFixed(2)}%`; }

export default rule;
