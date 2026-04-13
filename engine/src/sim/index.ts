import { config } from "../config/index.js";
import { simulateAnvil } from "./anvil.js";
import { simulateTenderly } from "./tenderly.js";
import type { QueuedTransaction, SimulationResult } from "../types.js";

export function simulate(tx: QueuedTransaction): Promise<SimulationResult> {
  return config.emulatorBackend === "tenderly"
    ? simulateTenderly(tx)
    : simulateAnvil(tx);
}
