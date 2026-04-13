export const FIREWALL_ABI = [
  {
    type: "event",
    name: "Queued",
    inputs: [
      { name: "id",        type: "bytes32", indexed: true },
      { name: "submitter", type: "address", indexed: true },
      { name: "target",    type: "address", indexed: true },
      { name: "value",     type: "uint256", indexed: false },
      { name: "data",      type: "bytes",   indexed: false },
    ],
  },
  {
    type: "event",
    name: "Executed",
    inputs: [{ name: "id", type: "bytes32", indexed: true }],
  },
  {
    type: "function",
    name: "approve",
    stateMutability: "nonpayable",
    inputs:  [{ name: "id", type: "bytes32" }],
    outputs: [],
  },
  {
    type: "function",
    name: "statusOf",
    stateMutability: "view",
    inputs:  [{ name: "id", type: "bytes32" }],
    outputs: [{ name: "", type: "uint8" }],  // 0 = Pending, 1 = Executed
  },
  {
    type: "function",
    name: "submittedAt",
    stateMutability: "view",
    inputs:  [{ name: "id", type: "bytes32" }],
    outputs: [{ name: "", type: "uint256" }],
  },
] as const;

// ── Chainlink AggregatorV3Interface (read-only) ─────────────────────────────────

export const CHAINLINK_AGGREGATOR_ABI = [
  {
    type: "function",
    name: "latestRoundData",
    stateMutability: "view",
    inputs:  [],
    outputs: [
      { name: "roundId",         type: "uint80"  },
      { name: "answer",          type: "int256"  },
      { name: "startedAt",       type: "uint256" },
      { name: "updatedAt",       type: "uint256" },
      { name: "answeredInRound", type: "uint80"  },
    ],
  },
  {
    type: "function",
    name: "decimals",
    stateMutability: "view",
    inputs:  [],
    outputs: [{ name: "", type: "uint8" }],
  },
] as const;

// ── Generic ERC-4626 vault ABI (used by the state reader) ──────────────────────

export const VAULT_ABI = [
  {
    type: "function",
    name: "totalAssets",
    stateMutability: "view",
    inputs:  [],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function",
    name: "totalSupply",
    stateMutability: "view",
    inputs:  [],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function",
    name: "convertToAssets",
    stateMutability: "view",
    inputs:  [{ name: "shares", type: "uint256" }],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function",
    name: "balanceOf",
    stateMutability: "view",
    inputs:  [{ name: "account", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
  },
] as const;
