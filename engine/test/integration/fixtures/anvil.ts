import { spawn, type ChildProcess } from "node:child_process";

const PORT_BASE = 28545;
let nextPort    = 0;

export interface AnvilInstance {
  rpcUrl:  string;
  port:    number;
  stop:    () => void;
}

async function waitForReady(rpcUrl: string, attempts = 50): Promise<void> {
  const body = JSON.stringify({ jsonrpc: "2.0", id: 1, method: "eth_chainId", params: [] });
  for (let i = 0; i < attempts; i++) {
    try {
      const res = await fetch(rpcUrl, {
        method:  "POST",
        headers: { "content-type": "application/json" },
        body,
      });
      if (res.ok) return;
    } catch {
      /* not up yet */
    }
    await new Promise((r) => setTimeout(r, 200));
  }
  throw new Error(`anvil at ${rpcUrl} never became available`);
}

/**
 * Start a fresh anvil instance on a unique port.
 * No fork — this is a pristine local chain for deploying test contracts.
 */
export async function startAnvil(): Promise<AnvilInstance> {
  const port   = PORT_BASE + (nextPort++ % 100);
  const rpcUrl = `http://127.0.0.1:${port}`;

  const proc: ChildProcess = spawn(
    "anvil",
    ["--port", String(port), "--silent", "--block-time", "1"],
    { stdio: "ignore" },
  );

  proc.on("error", (err) => {
    throw new Error(`failed to spawn anvil: ${err.message}`);
  });

  await waitForReady(rpcUrl);

  return {
    rpcUrl,
    port,
    stop: () => {
      proc.kill("SIGTERM");
    },
  };
}

/**
 * Default anvil dev accounts — deterministic across every invocation.
 * `anvil` prints these on startup; the mnemonic is "test test test test test test test test test test test junk".
 */
export const ANVIL_ACCOUNTS = [
  {
    address:    "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" as const,
    privateKey: "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" as const,
  },
  {
    address:    "0x70997970C51812dc3A010C7d01b50e0d17dc79C8" as const,
    privateKey: "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d" as const,
  },
  {
    address:    "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC" as const,
    privateKey: "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a" as const,
  },
  {
    address:    "0x90F79bf6EB2c4f870365E785982E1f101E93b906" as const,
    privateKey: "0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6" as const,
  },
] as const;
