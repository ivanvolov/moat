import type {
  ExternalData,
  ProtocolState,
  QueuedTransaction,
  RuleContext,
  StateDelta,
} from "../../src/types.js";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000" as const;

export function makeState(overrides: Partial<ProtocolState> = {}): ProtocolState {
  return {
    tvl:             BigInt(1_000e18),
    sharePrice:      BigInt(1e18),
    totalShares:     BigInt(1_000e18),
    contractBalance: BigInt(1_000e18),
    userShares:      BigInt(100e18),
    userBalance:     BigInt(100e18),
    extra:           {},
    ...overrides,
  };
}

export function makeDelta(before: ProtocolState, after: ProtocolState): StateDelta {
  return {
    tvl:             after.tvl             - before.tvl,
    sharePrice:      after.sharePrice      - before.sharePrice,
    totalShares:     after.totalShares     - before.totalShares,
    contractBalance: after.contractBalance - before.contractBalance,
    userShares:      after.userShares      - before.userShares,
    userBalance:     after.userBalance     - before.userBalance,
  };
}

export function makeTx(overrides: Partial<QueuedTransaction> = {}): QueuedTransaction {
  return {
    id:          "0x0000000000000000000000000000000000000000000000000000000000000001",
    submitter:   "0x1111111111111111111111111111111111111111",
    target:      "0x2222222222222222222222222222222222222222",
    value:       0n,
    data:        "0x",
    submittedAt: 0n,
    blockNumber: 0n,
    ...overrides,
  };
}

export function makeExternal(overrides: Partial<ExternalData> = {}): ExternalData {
  return { prices: {}, ...overrides };
}

export function makeContext(
  before: ProtocolState,
  after: ProtocolState,
  external: ExternalData = makeExternal(),
  tx: QueuedTransaction = makeTx(),
): RuleContext {
  return {
    tx,
    stateBefore: before,
    stateAfter:  after,
    delta:       makeDelta(before, after),
    external,
  };
}

export { ZERO_ADDRESS };
