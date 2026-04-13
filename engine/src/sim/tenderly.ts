import { createPublicClient, http } from "viem";
import { readProtocolState } from "./state.js";
import { config } from "../config/index.js";
import { chain } from "../config/chain.js";
import type { QueuedTransaction, SimulationResult } from "../types.js";

// Basic Tenderly simulate API. For full before/after state diffs, switch to
// the Tenderly fork API (create fork → send tx → read state → delete fork).

export async function simulateTenderly(tx: QueuedTransaction): Promise<SimulationResult> {
  const { account, project, accessKey } = config.tenderly;
  if (!account || !project || !accessKey)
    throw new Error("Tenderly backend requires TENDERLY_ACCOUNT, TENDERLY_PROJECT, TENDERLY_ACCESS_KEY");

  const res = await fetch(
    `https://api.tenderly.co/api/v1/account/${account}/project/${project}/simulate`,
    {
      method:  "POST",
      headers: { "content-type": "application/json", "x-access-key": accessKey },
      body:    JSON.stringify({
        network_id:    String(config.chainId),
        from:          tx.submitter,
        to:            tx.target,
        input:         tx.data,
        value:         tx.value.toString(),
        save:          false,
        save_if_fails: false,
      }),
    },
  );

  if (!res.ok) throw new Error(`Tenderly simulation failed (${res.status}): ${await res.text()}`);

  const { transaction } = await res.json() as { transaction: { status: boolean; error_message?: string } };

  const client      = createPublicClient({ chain, transport: http(config.rpcUrl) });
  const stateBefore = await readProtocolState(client, tx.target, tx.submitter);

  return {
    success:      transaction.status,
    revertReason: transaction.error_message,
    stateBefore,
    stateAfter:   { ...stateBefore },
  };
}
