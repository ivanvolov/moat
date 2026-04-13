import { type Address, isAddress } from "viem";

function env(key: string, fallback?: string): string {
  const v = process.env[key] ?? fallback;
  if (v === undefined) throw new Error(`Missing required env var: ${key}`);
  return v;
}

function envAddress(key: string): Address {
  const v = env(key);
  if (!isAddress(v)) throw new Error(`${key} is not a valid address: ${v}`);
  return v as Address;
}

function parseChainlinkFeeds(raw: string): Record<string, Address> {
  if (!raw.trim()) return {};
  return Object.fromEntries(
    raw.split(",").map((pair) => {
      const [label, addr] = pair.trim().split(":");
      if (!label || !addr) throw new Error(`Malformed CHAINLINK_FEEDS entry: ${pair}`);
      if (!isAddress(addr)) throw new Error(`Invalid Chainlink feed address for ${label}: ${addr}`);
      return [label, addr as Address];
    })
  );
}

export const config = {
  rpcUrl: env("RPC_URL"),
  chainId: Number(env("CHAIN_ID", "1")),

  firewallAddress: envAddress("FIREWALL_ADDRESS"),
  firewallDeployBlock: BigInt(env("FIREWALL_DEPLOY_BLOCK", "0")),

  watchtowerPrivateKey: env("WATCHTOWER_PRIVATE_KEY") as `0x${string}`,

  emulatorBackend: env("EMULATOR_BACKEND", "anvil") as "anvil" | "tenderly",
  anvilBin: env("ANVIL_BIN", "anvil"),

  tenderly: {
    account: env("TENDERLY_ACCOUNT", ""),
    project: env("TENDERLY_PROJECT", ""),
    accessKey: env("TENDERLY_ACCESS_KEY", ""),
  },

  chainlinkFeeds: parseChainlinkFeeds(env("CHAINLINK_FEEDS", "")),

  pollIntervalMs: Number(env("POLL_INTERVAL_MS", "2000")),
  evalTimeoutMs: Number(env("EVAL_TIMEOUT_MS", "15000")),
} as const;
