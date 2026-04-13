import type { Rule } from "../types.js";
import apyAnomaly        from "./apy-anomaly.js";
import tvlDrop           from "./tvl-drop.js";
import singleTransferCap from "./single-transfer-cap.js";

// Add new rules here. Files prefixed with _ are disabled by convention.
export function loadRules(): Rule[] {
  return [apyAnomaly, tvlDrop, singleTransferCap];
}
