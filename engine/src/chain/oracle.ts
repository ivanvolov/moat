import { createPublicClient, http, type Address } from "viem";
import { CHAINLINK_AGGREGATOR_ABI } from "./abis.js";
import { config } from "../config/index.js";
import { chain } from "../config/chain.js";
import { log } from "../logger.js";
import type { ExternalData } from "../types.js";

const client = createPublicClient({ chain, transport: http(config.rpcUrl) });

export async function fetchExternalData(): Promise<ExternalData> {
  const feeds = Object.entries(config.chainlinkFeeds) as [string, Address][];
  if (!feeds.length) return { prices: {} };

  const results = await Promise.allSettled(
    feeds.map(async ([label, feed]) => {
      const [, answer, , updatedAt] = await client.readContract({
        address: feed, abi: CHAINLINK_AGGREGATOR_ABI, functionName: "latestRoundData",
      });
      return { label, price: answer as bigint, updatedAt: updatedAt as bigint };
    }),
  );

  const prices: ExternalData["prices"] = {};
  for (let i = 0; i < results.length; i++) {
    const r     = results[i]!;
    const label = feeds[i]![0];
    if (r.status === "fulfilled") {
      prices[label] = { label, price: r.value.price, updatedAt: r.value.updatedAt };
    } else {
      log.warn({ label, reason: r.reason }, "chainlink feed fetch failed");
    }
  }

  return { prices };
}
