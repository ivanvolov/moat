import { describe, it, expect } from "vitest";
import rule from "../../../src/rules/tvl-drop.js";
import { makeContext, makeState } from "../fixtures.js";

describe("tvl-drop rule", () => {
  it("passes when tvl does not decrease", async () => {
    const before = makeState({ tvl: BigInt(1_000e18) });
    const after  = makeState({ tvl: BigInt(1_000e18) });
    const result = await rule.evaluate(makeContext(before, after));
    expect(result.pass).toBe(true);
  });

  it("passes when tvl drop is within the 5% cap", async () => {
    const before = makeState({ tvl: BigInt(1_000e18) });
    const after  = makeState({ tvl: BigInt(960e18) }); // 4% drop
    const result = await rule.evaluate(makeContext(before, after));
    expect(result.pass).toBe(true);
  });

  it("blocks when tvl drop exceeds the 5% cap", async () => {
    const before = makeState({ tvl: BigInt(1_000e18) });
    const after  = makeState({ tvl: BigInt(900e18) }); // 10% drop
    const result = await rule.evaluate(makeContext(before, after));
    expect(result.pass).toBe(false);
    expect(result.reason).toMatch(/tvl would drop/);
  });

  it("skips enforcement when tvl is below the minimum threshold", async () => {
    const before = makeState({ tvl: BigInt(0.5e18) });
    const after  = makeState({ tvl: 0n }); // 100% drop
    const result = await rule.evaluate(makeContext(before, after));
    expect(result.pass).toBe(true);
    expect(result.reason).toMatch(/below minimum/);
  });

  it("passes when tvl increases", async () => {
    const before = makeState({ tvl: BigInt(1_000e18) });
    const after  = makeState({ tvl: BigInt(1_100e18) });
    const result = await rule.evaluate(makeContext(before, after));
    expect(result.pass).toBe(true);
  });
});
