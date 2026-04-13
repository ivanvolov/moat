import { loadRules } from "./rules/_registry.js";
import { config } from "./config/index.js";
import { log } from "./logger.js";
import type { RuleContext, RuleResult, Verdict } from "./types.js";

const rules = loadRules();
log.info({ rules: rules.map((r) => r.id) }, `${rules.length} rule(s) loaded`);

function withTimeout(fn: () => Promise<RuleResult>, id: string): Promise<RuleResult> {
  return new Promise((resolve, reject) => {
    const t = setTimeout(
      () => resolve({ pass: true, reason: `timed out after ${config.evalTimeoutMs}ms` }),
      config.evalTimeoutMs,
    );
    fn().then(
      (r) => { clearTimeout(t); resolve(r); },
      (e) => { clearTimeout(t); reject(e); },
    );
  });
}

export async function evaluate(ctx: RuleContext): Promise<Verdict> {
  const settled = await Promise.allSettled(
    rules.map((rule) => withTimeout(() => rule.evaluate(ctx), rule.id)),
  );

  const breakdown: Verdict["breakdown"] = [];
  const failures: string[] = [];

  for (let i = 0; i < settled.length; i++) {
    const rule    = rules[i]!;
    const outcome = settled[i]!;

    if (outcome.status === "rejected") {
      log.error({ rule: rule.id, err: outcome.reason }, "rule threw — fail-open");
      breakdown.push({ rule: rule.id, result: { pass: true, reason: "error (fail-open)" } });
      continue;
    }

    const result = outcome.value;
    breakdown.push({ rule: rule.id, result });

    if (!result.pass) {
      failures.push(`[${rule.id}] ${result.reason}`);
      log.warn({ rule: rule.id, reason: result.reason }, "rule blocked tx");
    }
  }

  return { approved: failures.length === 0, reason: failures.join(" | "), breakdown };
}
