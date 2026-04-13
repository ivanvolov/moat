import { createPublicClient, http, webSocket, type Hex } from "viem";
import { FIREWALL_ABI } from "./chain/abis.js";
import { fetchExternalData } from "./chain/oracle.js";
import { submitApprove } from "./chain/watchtower.js";
import { config } from "./config/index.js";
import { chain } from "./config/chain.js";
import { log } from "./logger.js";
import { simulate } from "./sim/index.js";
import { evaluate } from "./runner.js";
import type { QueuedTransaction, StateDelta } from "./types.js";

type QueuedArgs = { id: Hex; submitter: `0x${string}`; target: `0x${string}`; value: bigint; data: Hex };

async function process(args: QueuedArgs, blockNumber: bigint): Promise<void> {
  const tx: QueuedTransaction = {
    id:          args.id,
    submitter:   args.submitter,
    target:      args.target,
    value:       args.value ?? 0n,
    data:        args.data ?? "0x",
    submittedAt: BigInt(Math.floor(Date.now() / 1000)),
    blockNumber,
  };

  log.info({ txId: tx.id, submitter: tx.submitter, target: tx.target }, "queued");

  try {
    const sim = await simulate(tx);

    if (!sim.success) {
      log.warn({ txId: tx.id, reason: sim.revertReason }, "simulation reverted — withholding approval, timelock applies");
      return;
    }

    const delta: StateDelta = {
      tvl:             sim.stateAfter.tvl             - sim.stateBefore.tvl,
      sharePrice:      sim.stateAfter.sharePrice      - sim.stateBefore.sharePrice,
      totalShares:     sim.stateAfter.totalShares     - sim.stateBefore.totalShares,
      contractBalance: sim.stateAfter.contractBalance - sim.stateBefore.contractBalance,
      userShares:      sim.stateAfter.userShares      - sim.stateBefore.userShares,
      userBalance:     sim.stateAfter.userBalance     - sim.stateBefore.userBalance,
    };

    const external = await fetchExternalData();
    const verdict  = await evaluate({ tx, stateBefore: sim.stateBefore, stateAfter: sim.stateAfter, delta, external });

    if (verdict.approved) {
      log.info({ txId: tx.id }, "approved");
      await submitApprove(tx.id);
    } else {
      log.warn({ txId: tx.id, reason: verdict.reason }, "blocked — withholding approval, timelock applies");
    }
  } catch (err) {
    log.error({ txId: tx.id, err }, "pipeline error — tx left pending, timelock applies");
  }
}

export function watch(): () => void {
  const isWs   = config.rpcUrl.startsWith("ws");
  const client = createPublicClient({ chain, transport: isWs ? webSocket(config.rpcUrl) : http(config.rpcUrl) });

  log.info({ address: config.firewallAddress, via: isWs ? "ws" : "poll" }, "watching firewall");

  if (isWs) {
    return client.watchContractEvent({
      address:   config.firewallAddress,
      abi:       FIREWALL_ABI,
      eventName: "Queued",
      onLogs:    (logs) => { for (const l of logs) void process(l.args as QueuedArgs, l.blockNumber ?? 0n); },
    });
  }

  let fromBlock = config.firewallDeployBlock;
  const poll = async () => {
    try {
      const latest = await client.getBlockNumber();
      if (latest >= fromBlock) {
        const logs = await client.getContractEvents({
          address: config.firewallAddress, abi: FIREWALL_ABI, eventName: "Queued",
          fromBlock, toBlock: latest,
        });
        for (const l of logs) void process(l.args as QueuedArgs, l.blockNumber ?? 0n);
        fromBlock = latest + 1n;
      }
    } catch (err) {
      log.error({ err }, "poll error");
    }
  };

  void poll();
  const interval = setInterval(() => void poll(), config.pollIntervalMs);
  return () => clearInterval(interval);
}
