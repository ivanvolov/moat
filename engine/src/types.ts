import type { Address, Hex } from "viem";

export interface QueuedTransaction {
  id:          Hex;
  submitter:   Address;
  target:      Address;
  value:       bigint;
  data:        Hex;
  submittedAt: bigint;
  blockNumber: bigint;
}

export interface ProtocolState {
  tvl:             bigint;
  sharePrice:      bigint; // assets per 1e18 shares
  totalShares:     bigint;
  contractBalance: bigint;
  userShares:      bigint;
  userBalance:     bigint;
  extra:           Record<string, bigint>;
}

export interface StateDelta {
  tvl:             bigint;
  sharePrice:      bigint;
  totalShares:     bigint;
  contractBalance: bigint;
  userShares:      bigint;
  userBalance:     bigint;
}

export interface OraclePrice {
  label:     string;
  price:     bigint; // 8-decimal Chainlink answer
  updatedAt: bigint;
}

export interface ExternalData {
  prices: Record<string, OraclePrice>;
}

export interface RuleContext {
  tx:          QueuedTransaction;
  stateBefore: ProtocolState;
  stateAfter:  ProtocolState;
  delta:       StateDelta;
  external:    ExternalData;
}

export interface RuleResult {
  pass:   boolean;
  reason: string;
}

export interface Rule {
  id:          string;
  description: string;
  evaluate(ctx: RuleContext): Promise<RuleResult>;
}

export interface SimulationResult {
  success:      boolean;
  revertReason: string | undefined;
  stateBefore:  ProtocolState;
  stateAfter:   ProtocolState;
}

export interface Verdict {
  approved:    boolean;
  reason:      string;
  breakdown:   Array<{ rule: string; result: RuleResult }>;
}
