import { type PublicClient, type Address } from "viem";
import { VAULT_ABI } from "../chain/abis.js";
import type { ProtocolState } from "../types.js";

const ONE_SHARE = BigInt(1e18);

async function tryRead<T>(fn: () => Promise<T>, fallback: T): Promise<T> {
  try { return await fn(); } catch { return fallback; }
}

export async function readProtocolState(
  client:  PublicClient,
  target:  Address,
  user:    Address,
): Promise<ProtocolState> {
  const [tvl, totalShares, userShares, sharePrice, contractBalance, userBalance] = await Promise.all([
    tryRead(() => client.readContract({ address: target, abi: VAULT_ABI, functionName: "totalAssets" }), 0n),
    tryRead(() => client.readContract({ address: target, abi: VAULT_ABI, functionName: "totalSupply" }), 0n),
    tryRead(() => client.readContract({ address: target, abi: VAULT_ABI, functionName: "balanceOf", args: [user] }), 0n),
    tryRead(() => client.readContract({ address: target, abi: VAULT_ABI, functionName: "convertToAssets", args: [ONE_SHARE] }), ONE_SHARE),
    tryRead(() => client.getBalance({ address: target }), 0n),
    tryRead(() => client.getBalance({ address: user }), 0n),
  ]);

  return { tvl, sharePrice, totalShares, contractBalance, userShares, userBalance, extra: {} };
}
