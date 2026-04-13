import "dotenv/config";
import { watch } from "./watcher.js";
import { log } from "./logger.js";

log.info("moat engine starting");

const stop = watch();

process.on("SIGINT",  () => { stop(); process.exit(0); });
process.on("SIGTERM", () => { stop(); process.exit(0); });
