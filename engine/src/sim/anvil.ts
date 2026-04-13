import { createPublicClient, createWalletClient, http } from "viem";
import { spawn } from "node:child_process";
import { readProtocolState } from "./state.js";
import { config } from "../config/index.js";
import { chain } from "../config/chain.js";
import { log } from "../logger.js";
import type { QueuedTransaction, SimulationResult } from "../types.js";

let portSeq   = 0;
const PORT_BASE = 18545;

async function rpcReady(url: string, attempts = 20): Promise<void> {
  const body = JSON.stringify({ jsonrpc: "2.0", id: 1, method: "eth_chainId", params: [] });
  for (let i = 0; i < attempts; i++) {
    try {
      if ((await fetch(url, { method: "POST", headers: { "content-type": "application/json" }, body })).ok)
        return;
    } catch { /* not up yet */ }
    await new Promise((r) => setTimeout(r, 300));
  }
  throw new Error(`anvil at ${url} never became available`);
}

export async function simulateAnvil(tx: QueuedTransaction): Promise<SimulationResult> {
  const port      = PORT_BASE + (portSeq++ % 100);
  const forkRpc   = `http://127.0.0.1:${port}`;
  const forkChain = { ...chain, rpcUrls: { default: { http: [forkRpc] } } };

  const proc = spawn(
    config.anvilBin,
    ["--port", String(port), "--fork-url", config.rpcUrl, "--no-mining", "--silent"],
    { stdio: "pipe" },
  );
  proc.on("error", (err) => { throw err; });

  try {
    await rpcReady(forkRpc);

    const fork        = createPublicClient({ chain: forkChain, transport: http(forkRpc) });
    const stateBefore = await readProtocolState(fork, tx.target, tx.submitter);

    await fetch(forkRpc, {
      method:  "POST",
      headers: { "content-type": "application/json" },
      body:    JSON.stringify({ jsonrpc: "2.0", id: 1, method: "anvil_impersonateAccount", params: [tx.submitter] }),
    });

    let success      = true;
    let revertReason: string | undefined;

    try {
      const wallet = createWalletClient({ chain: forkChain, transport: http(forkRpc) });
      await wallet.sendTransaction({ account: tx.submitter, to: tx.target, value: tx.value, data: tx.data, chain: forkChain });
    } catch (err) {
      success      = false;
      revertReason = err instanceof Error ? err.message : String(err);
      log.debug({ txId: tx.id, revertReason }, "simulated tx reverted");
    }

    const stateAfter = await readProtocolState(fork, tx.target, tx.submitter);

    return { success, revertReason, stateBefore, stateAfter };
  } finally {
    proc.kill("SIGTERM");
  }
}
