import { defineChain } from "viem";
import { config } from "./index.js";

// Build a minimal chain descriptor from config so all clients use the right chainId.
// Covers local Anvil (31337), testnets, and mainnet (1) without hardcoding.
export const chain = defineChain({
  id:   config.chainId,
  name: config.chainId === 1 ? "Ethereum" : `chain-${config.chainId}`,
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: { default: { http: [config.rpcUrl] } },
});
