import { describe, it, expect } from "vitest";
import rule from "../../../src/rules/single-transfer-cap.js";
import { makeContext, makeState } from "../fixtures.js";

describe("single-transfer-cap rule", () => {
  it("passes when the user did not reduce their share balance", async () => {
    const before = makeState({ userShares: BigInt(100e18) });
    const after  = makeState({ userShares: BigInt(100e18) });
    const result = await rule.evaluate(makeContext(before, after));
    expect(result.pass).toBe(true);
  });

  it("blocks when extraction exceeds the absolute 100 ETH ceiling", async () => {
    const before = makeState({
      userShares: BigInt(200e18),
      sharePrice: BigInt(1e18),
      tvl:        BigInt(10_000e18),
    });
    const after = makeState({
      userShares: BigInt(50e18),   // withdrew 150e18 ≈ 150 ETH
      sharePrice: BigInt(1e18),
      tvl:        BigInt(9_850e18),
    });
    const result = await rule.evaluate(makeContext(before, after));
    expect(result.pass).toBe(false);
    expect(result.reason).toMatch(/hard cap/);
  });

  it("blocks when extraction exceeds 10% of TVL", async () => {
    const before = makeState({
      userShares: BigInt(90e18),
      sharePrice: BigInt(1e18),
      tvl:        BigInt(500e18),
    });
    const after = makeState({
      userShares: 0n,              // withdrew 90e18 = 18% of TVL
      sharePrice: BigInt(1e18),
      tvl:        BigInt(410e18),
    });
    const result = await rule.evaluate(makeContext(before, after));
    expect(result.pass).toBe(false);
    expect(result.reason).toMatch(/exceeds per-call cap/);
  });

  it("passes when extraction is within both caps", async () => {
    const before = makeState({
      userShares: BigInt(100e18),
      sharePrice: BigInt(1e18),
      tvl:        BigInt(10_000e18),
    });
    const after = makeState({
      userShares: BigInt(90e18),   // 10e18 extracted, 0.1% of TVL
      sharePrice: BigInt(1e18),
      tvl:        BigInt(9_990e18),
    });
    const result = await rule.evaluate(makeContext(before, after));
    expect(result.pass).toBe(true);
  });

  it("accounts for share price when computing extracted value", async () => {
    // 60 shares * 2 ETH/share = 120 ETH, over the 100 ETH cap
    const before = makeState({
      userShares: BigInt(100e18),
      sharePrice: BigInt(2e18),
      tvl:        BigInt(100_000e18),
    });
    const after = makeState({
      userShares: BigInt(40e18),
      sharePrice: BigInt(2e18),
      tvl:        BigInt(99_880e18),
    });
    const result = await rule.evaluate(makeContext(before, after));
    expect(result.pass).toBe(false);
    expect(result.reason).toMatch(/hard cap/);
  });
});
