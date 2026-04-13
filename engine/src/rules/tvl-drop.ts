// Blocks any single call that drains more than MAX_DROP_BPS of protocol TVL.
// Catches drain attacks regardless of which function is called or who profits.

import type { Rule, RuleContext, RuleResult } from "../types.js";

const MAX_DROP_BPS = 500n;           // 5% per call
const MIN_TVL      = BigInt(1e18);   // skip check on bootstrapping pools below 1 ETH-eq
const BPS          = 10_000n;

const rule: Rule = {
  id:          "tvl-drop",
  description: "Blocks transactions that remove more than 5% of TVL in a single call.",

  async evaluate({ stateBefore, stateAfter }: RuleContext): Promise<RuleResult> {
    if (stateBefore.tvl < MIN_TVL)
      return { pass: true, reason: "tvl below minimum enforcement threshold" };

    if (stateAfter.tvl >= stateBefore.tvl)
      return { pass: true, reason: "tvl did not decrease" };

    const drop    = stateBefore.tvl - stateAfter.tvl;
    const dropBps = (drop * BPS) / stateBefore.tvl;

    if (dropBps > MAX_DROP_BPS)
      return {
        pass:   false,
        reason: `tvl would drop ${pct(dropBps)} (${eth(drop)} ETH-eq), cap is ${pct(MAX_DROP_BPS)}`,
      };

    return { pass: true, reason: `tvl drop ${pct(dropBps)} within cap` };
  },
};

function pct(bps: bigint): string { return `${(Number(bps) / 100).toFixed(2)}%`; }
function eth(wei: bigint): string { return (Number(wei) / 1e18).toFixed(4); }

export default rule;
