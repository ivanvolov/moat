import { createPublicClient, createWalletClient, http, type Hex } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { FIREWALL_ABI } from "./abis.js";
import { config } from "../config/index.js";
import { chain } from "../config/chain.js";
import { log } from "../logger.js";

const account = privateKeyToAccount(config.watchtowerPrivateKey);
const pub     = createPublicClient({ chain, transport: http(config.rpcUrl) });
const wallet  = createWalletClient({ account, chain, transport: http(config.rpcUrl) });

export async function submitApprove(txId: Hex): Promise<void> {
  log.info({ txId }, "approve");
  const hash    = await wallet.writeContract({ address: config.firewallAddress, abi: FIREWALL_ABI, functionName: "approve", args: [txId] });
  const receipt = await pub.waitForTransactionReceipt({ hash });
  log.info({ txId, hash, block: receipt.blockNumber }, "approved");
}
