import { readFileSync, existsSync } from "node:fs";
import { resolve } from "node:path";
import type { Abi, Hex } from "viem";

const ARTIFACT_ROOT = resolve(
  import.meta.dirname,
  "../../../../firewall/out",
);

export interface Artifact {
  abi:      Abi;
  bytecode: Hex;
}

export function loadArtifact(sourceFile: string, contractName: string): Artifact {
  const path = resolve(ARTIFACT_ROOT, sourceFile, `${contractName}.json`);
  if (!existsSync(path)) {
    throw new Error(
      `Artifact not found: ${path}\n` +
      `Run \`cd ../firewall && forge build\` before running integration tests.`,
    );
  }
  const json = JSON.parse(readFileSync(path, "utf-8")) as {
    abi:      Abi;
    bytecode: { object: Hex };
  };
  return { abi: json.abi, bytecode: json.bytecode.object };
}
