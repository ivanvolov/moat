import { describe, it, expect, beforeAll, afterAll } from "vitest";
import {
  createPublicClient,
  createWalletClient,
  http,
  parseEther,
  encodeFunctionData,
  getContract,
  type Address,
  type Hex,
  type PublicClient,
  type WalletClient,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { foundry } from "viem/chains";

import { startAnvil, ANVIL_ACCOUNTS, type AnvilInstance } from "./fixtures/anvil.js";
import { loadArtifact } from "./fixtures/artifacts.js";

const TIMELOCK = 3600n;

let anvil:      AnvilInstance;
let pub:        PublicClient;
let deployer:   WalletClient;
let watchtower: WalletClient;
let alice:      WalletClient;

let firewallAddress: Address;
let mockTarget:      Address;

const firewallArtifact = loadArtifact("MoatFirewall.sol", "MoatFirewall");
const erc20Artifact    = loadArtifact("ERC20Mock.sol", "ERC20Mock");

const [adminAcct, watchtowerAcct, aliceAcct] = ANVIL_ACCOUNTS;

beforeAll(async () => {
  anvil = await startAnvil();

  const transport = http(anvil.rpcUrl);
  pub        = createPublicClient({ chain: foundry, transport });
  deployer   = createWalletClient({ account: privateKeyToAccount(adminAcct.privateKey),      chain: foundry, transport });
  watchtower = createWalletClient({ account: privateKeyToAccount(watchtowerAcct.privateKey), chain: foundry, transport });
  alice      = createWalletClient({ account: privateKeyToAccount(aliceAcct.privateKey),      chain: foundry, transport });

  // Deploy MoatFirewall(admin, watchtower, timelock)
  const fwHash = await deployer.deployContract({
    abi:      firewallArtifact.abi,
    bytecode: firewallArtifact.bytecode,
    args:     [adminAcct.address, watchtowerAcct.address, TIMELOCK],
    chain:    foundry,
    account:  deployer.account!,
  });
  const fwReceipt = await pub.waitForTransactionReceipt({ hash: fwHash });
  if (!fwReceipt.contractAddress) throw new Error("firewall deployment failed");
  firewallAddress = fwReceipt.contractAddress;

  // Deploy a throwaway ERC20Mock just to have a whitelistable target contract
  const mockHash = await deployer.deployContract({
    abi:      erc20Artifact.abi,
    bytecode: erc20Artifact.bytecode,
    args:     ["Target", "TGT"],
    chain:    foundry,
    account:  deployer.account!,
  });
  const mockReceipt = await pub.waitForTransactionReceipt({ hash: mockHash });
  if (!mockReceipt.contractAddress) throw new Error("mock deployment failed");
  mockTarget = mockReceipt.contractAddress;

  // Whitelist the target as admin
  const allowHash = await deployer.writeContract({
    address:      firewallAddress,
    abi:          firewallArtifact.abi,
    functionName: "allow",
    args:         [mockTarget],
    chain:        foundry,
    account:      deployer.account!,
  });
  await pub.waitForTransactionReceipt({ hash: allowHash });
}, 60_000);

afterAll(() => {
  anvil?.stop();
});

describe("firewall end-to-end on anvil", () => {
  it("deploys the firewall with correct initial state", async () => {
    const firewall = getContract({ address: firewallAddress, abi: firewallArtifact.abi, client: pub });
    const admin      = (await firewall.read.admin()) as Address;
    const wtAddr     = (await firewall.read.watchtower()) as Address;
    const duration   = (await firewall.read.timelockDuration()) as bigint;
    const whitelisted = (await firewall.read.whitelist([mockTarget])) as boolean;

    expect(admin.toLowerCase()).toBe(adminAcct.address.toLowerCase());
    expect(wtAddr.toLowerCase()).toBe(watchtowerAcct.address.toLowerCase());
    expect(duration).toBe(TIMELOCK);
    expect(whitelisted).toBe(true);
  });

  it("submit → Queued event → watchtower approve → Executed", async () => {
    // Encode a harmless call: ERC20Mock.mint(alice, 0) on the target
    const data: Hex = encodeFunctionData({
      abi:          erc20Artifact.abi,
      functionName: "mint",
      args:         [aliceAcct.address, 0n],
    });

    // Alice submits through the firewall (no ETH, no token transfer)
    const submitHash = await alice.writeContract({
      address:      firewallAddress,
      abi:          firewallArtifact.abi,
      functionName: "submit",
      args:         [mockTarget, 0n, "0x0000000000000000000000000000000000000000", 0n, data],
      chain:        foundry,
      account:      alice.account!,
    });
    const submitReceipt = await pub.waitForTransactionReceipt({ hash: submitHash });

    // Find the Queued event
    const queuedLogs = await pub.getContractEvents({
      address:     firewallAddress,
      abi:         firewallArtifact.abi,
      eventName:   "Queued",
      fromBlock:   submitReceipt.blockNumber,
      toBlock:     submitReceipt.blockNumber,
    });
    expect(queuedLogs).toHaveLength(1);
    const queuedEvent = queuedLogs[0]!;
    const txId = (queuedEvent.args as { id: Hex }).id;
    expect(txId).toBeDefined();

    // Status should be Pending (0)
    const statusBefore = (await pub.readContract({
      address:      firewallAddress,
      abi:          firewallArtifact.abi,
      functionName: "statusOf",
      args:         [txId],
    })) as number;
    expect(statusBefore).toBe(0);

    // Watchtower approves
    const approveHash = await watchtower.writeContract({
      address:      firewallAddress,
      abi:          firewallArtifact.abi,
      functionName: "approve",
      args:         [txId],
      chain:        foundry,
      account:      watchtower.account!,
    });
    const approveReceipt = await pub.waitForTransactionReceipt({ hash: approveHash });

    // Status should be Executed (1)
    const statusAfter = (await pub.readContract({
      address:      firewallAddress,
      abi:          firewallArtifact.abi,
      functionName: "statusOf",
      args:         [txId],
    })) as number;
    expect(statusAfter).toBe(1);

    // Executed event should have been emitted
    const executedLogs = await pub.getContractEvents({
      address:     firewallAddress,
      abi:         firewallArtifact.abi,
      eventName:   "Executed",
      fromBlock:   approveReceipt.blockNumber,
      toBlock:     approveReceipt.blockNumber,
    });
    expect(executedLogs).toHaveLength(1);
  });

  it("non-watchtower cannot approve", async () => {
    const data: Hex = encodeFunctionData({
      abi:          erc20Artifact.abi,
      functionName: "mint",
      args:         [aliceAcct.address, 0n],
    });

    const submitHash = await alice.writeContract({
      address:      firewallAddress,
      abi:          firewallArtifact.abi,
      functionName: "submit",
      args:         [mockTarget, 0n, "0x0000000000000000000000000000000000000000", 0n, data],
      chain:        foundry,
      account:      alice.account!,
    });
    const submitReceipt = await pub.waitForTransactionReceipt({ hash: submitHash });
    const queuedLogs    = await pub.getContractEvents({
      address:   firewallAddress,
      abi:       firewallArtifact.abi,
      eventName: "Queued",
      fromBlock: submitReceipt.blockNumber,
      toBlock:   submitReceipt.blockNumber,
    });
    const txId = (queuedLogs[0]!.args as { id: Hex }).id;

    await expect(
      alice.writeContract({
        address:      firewallAddress,
        abi:          firewallArtifact.abi,
        functionName: "approve",
        args:         [txId],
        chain:        foundry,
        account:      alice.account!,
      }),
    ).rejects.toThrow(/Unauthorized/);
  });
});
