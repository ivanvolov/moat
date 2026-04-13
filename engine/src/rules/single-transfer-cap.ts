// Limits how much a single user can extract in one call.
// Complements tvl-drop: catches disproportionate user-level extraction even
// when total TVL impact stays inside tolerance (e.g. unsettled accounting).

import type { Rule, RuleContext, RuleResult } from "../types.js";

const MAX_WEI  = BigInt(100e18);  // 100 ETH-eq absolute ceiling; 0n = disabled
const MAX_BPS  = 1_000n;          // 10% of TVL per call; 0n = disabled
const MIN_TVL  = BigInt(1e18);
const BPS      = 10_000n;
const ONE_E18  = BigInt(1e18);

const rule: Rule = {
  id:          "single-transfer-cap",
  description: "Blocks a single user from extracting more than 100 ETH-eq or 10% of TVL in one call.",

  async evaluate({ stateBefore, stateAfter }: RuleContext): Promise<RuleResult> {
    const shareReduction = stateBefore.userShares - stateAfter.userShares;
    if (shareReduction <= 0n)
      return { pass: true, reason: "no share reduction" };

    const extracted = stateBefore.sharePrice > 0n
      ? (shareReduction * stateBefore.sharePrice) / ONE_E18
      : shareReduction;

    if (MAX_WEI > 0n && extracted > MAX_WEI)
      return { pass: false, reason: `extraction ${eth(extracted)} ETH-eq exceeds hard cap ${eth(MAX_WEI)}` };

    if (MAX_BPS > 0n && stateBefore.tvl >= MIN_TVL) {
      const bps = (extracted * BPS) / stateBefore.tvl;
      if (bps > MAX_BPS)
        return { pass: false, reason: `extraction ${pct(bps)} of TVL exceeds per-call cap ${pct(MAX_BPS)}` };
    }

    return { pass: true, reason: `extraction ${eth(extracted)} ETH-eq within bounds` };
  },
};

function pct(bps: bigint): string { return `${(Number(bps) / 100).toFixed(2)}%`; }
function eth(wei: bigint): string { return (Number(wei) / 1e18).toFixed(4); }

export default rule;
