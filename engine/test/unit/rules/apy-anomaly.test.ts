import { describe, it, expect } from "vitest";
import rule from "../../../src/rules/apy-anomaly.js";
import { makeContext, makeExternal, makeState } from "../fixtures.js";

describe("apy-anomaly rule", () => {
  it("passes when share price is unchanged", async () => {
    const before = makeState({ sharePrice: BigInt(1e18) });
    const after  = makeState({ sharePrice: BigInt(1e18) });
    const result = await rule.evaluate(makeContext(before, after));
    expect(result.pass).toBe(true);
  });

  it("passes when share price decreases", async () => {
    const before = makeState({ sharePrice: BigInt(1e18) });
    const after  = makeState({ sharePrice: BigInt(0.99e18) });
    const result = await rule.evaluate(makeContext(before, after));
    expect(result.pass).toBe(true);
  });

  it("passes when there was no share price before the tx", async () => {
    const before = makeState({ sharePrice: 0n });
    const after  = makeState({ sharePrice: BigInt(1e18) });
    const result = await rule.evaluate(makeContext(before, after));
    expect(result.pass).toBe(true);
  });

  it("blocks when implied APY exceeds the 50% ceiling", async () => {
    // A 1% jump in a single 12-second block annualises to ~2.6m% APY
    const before = makeState({ sharePrice: BigInt(1e18) });
    const after  = makeState({ sharePrice: BigInt(1.01e18) });
    const result = await rule.evaluate(makeContext(before, after));
    expect(result.pass).toBe(false);
    expect(result.reason).toMatch(/implied APY/);
  });

  it("passes when implied APY is well below the ceiling", async () => {
    // A minuscule per-block increment → tiny annualised APY
    const before = makeState({ sharePrice: BigInt(1e18) });
    const after  = makeState({ sharePrice: BigInt(1e18) + 100n });
    const result = await rule.evaluate(makeContext(before, after));
    expect(result.pass).toBe(true);
  });

  it("uses oracle baseline when provided", async () => {
    const before = makeState({ sharePrice: BigInt(1e18) });
    const after  = makeState({ sharePrice: BigInt(1.001e18) });
    const external = makeExternal({
      prices: {
        ETH_USD: { label: "ETH_USD", price: 3_000n * BigInt(1e8), updatedAt: 0n },
      },
    });
    const result = await rule.evaluate(makeContext(before, after, external));
    expect(result.pass).toBe(false);
  });
});
