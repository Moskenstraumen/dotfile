// Emulates Claude Code's `cleanupPeriodDays`: delete pi session files older than RETENTION_DAYS.
//
// On session_start (at most once per MIN_INTERVAL_MS across all pi processes, tracked in
// <agentDir>/state/session-cleanup.json) scan <sessions>/--<encoded-cwd>--/*.jsonl and unlink
// files whose mtime is older than the retention window, plus their same-stem sibling dir
// (subagent child sessions). The current session file is never touched. subagent-artifacts/,
// permission-forwarding/ and anything not matching those shapes is left alone. Emptied
// --cwd-- dirs are removed. Runs fire-and-forget; fails open: errors are swallowed.
//
// Override retention with PI_SESSION_RETENTION_DAYS (positive number); "0" disables cleanup.
// `/session-cleanup [--dry-run]` runs immediately, ignoring the throttle.
//
// Main session only: skipped when PI_SUBAGENT_CHILD=1.

import { getAgentDir, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";
import * as fs from "node:fs/promises";
import * as path from "node:path";

const RETENTION_DAYS = 30;
const MIN_INTERVAL_MS = 24 * 60 * 60 * 1000;
const DAY_MS = 86_400_000;
function stateFile(): string {
	return path.join(getAgentDir(), "state/session-cleanup.json");
}

/** Returns retention days, or 0 when cleanup is disabled. */
function retentionDays(): number {
	const raw = process.env.PI_SESSION_RETENTION_DAYS;
	if (raw === undefined || raw.trim() === "") return RETENTION_DAYS;
	if (raw.trim() === "0") return 0;
	const n = Number(raw);
	return Number.isFinite(n) && n > 0 ? n : RETENTION_DAYS;
}

function sessionsRoot(ctx: ExtensionContext): string {
	try {
		const dir = ctx.sessionManager.getSessionDir();
		if (dir) return path.dirname(dir);
	} catch {}
	return path.join(getAgentDir(), "sessions");
}

function currentFile(ctx: ExtensionContext): string | undefined {
	try {
		const f = ctx.sessionManager.getSessionFile();
		return f ? path.resolve(f) : undefined;
	} catch {
		return undefined;
	}
}

/** Deletes (or, with dryRun, lists) expired top-level session files. Returns their paths. */
export async function cleanupSessions(
	root: string,
	opts: { retentionDays: number; currentFile?: string; dryRun?: boolean; now?: number },
): Promise<string[]> {
	const cutoff = (opts.now ?? Date.now()) - opts.retentionDays * DAY_MS;
	const current = opts.currentFile ? path.resolve(opts.currentFile) : undefined;
	const removed: string[] = [];
	let entries;
	try {
		entries = await fs.readdir(root, { withFileTypes: true });
	} catch {
		return removed;
	}
	for (const cwdEntry of entries) {
		if (!cwdEntry.isDirectory() || !/^--.*--$/.test(cwdEntry.name)) continue;
		const dir = path.join(root, cwdEntry.name);
		try {
			for (const f of await fs.readdir(dir, { withFileTypes: true })) {
				if (!f.isFile() || !f.name.endsWith(".jsonl")) continue;
				const file = path.resolve(dir, f.name);
				if (file === current) continue;
				try {
					if ((await fs.stat(file)).mtimeMs >= cutoff) continue;
					removed.push(file);
					if (opts.dryRun) continue;
					await fs.unlink(file).catch((e) => {
						if (e?.code !== "ENOENT") throw e;
					});
					const sibling = path.join(dir, f.name.slice(0, -".jsonl".length));
					const st = await fs.lstat(sibling).catch(() => undefined);
					if (st?.isDirectory()) await fs.rm(sibling, { recursive: true, force: true });
				} catch {}
			}
			if (!opts.dryRun && (await fs.readdir(dir)).length === 0) await fs.rmdir(dir).catch(() => {});
		} catch {}
	}
	return removed;
}

async function throttled(): Promise<boolean> {
	const file = stateFile();
	try {
		const { lastRun } = JSON.parse(await fs.readFile(file, "utf8"));
		if (typeof lastRun === "number" && Date.now() - lastRun < MIN_INTERVAL_MS) return true;
	} catch {}
	await fs.mkdir(path.dirname(file), { recursive: true });
	await fs.writeFile(file, JSON.stringify({ lastRun: Date.now() }));
	return false;
}

export default function sessionCleanup(pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		try {
			if (process.env.PI_SUBAGENT_CHILD === "1") return;
			const days = retentionDays();
			if (days === 0) return;
			const run = async () => {
				if (await throttled()) return;
				const removed = await cleanupSessions(sessionsRoot(ctx), { retentionDays: days, currentFile: currentFile(ctx) });
				if (removed.length > 0 && ctx.hasUI)
					ctx.ui.notify(`session-cleanup: removed ${removed.length} session(s) older than ${days} days`, "info");
			};
			void run().catch(() => {});
		} catch {}
	});

	pi.registerCommand("session-cleanup", {
		description: "Delete pi sessions older than the retention window now (--dry-run to list only)",
		handler: async (args, ctx) => {
			try {
				const days = retentionDays();
				if (days === 0) {
					ctx.ui.notify("session-cleanup: disabled (PI_SESSION_RETENTION_DAYS=0)", "info");
					return;
				}
				const dryRun = /(^|\s)--dry-run(\s|$)/.test(args ?? "");
				const root = sessionsRoot(ctx);
				const found = await cleanupSessions(root, { retentionDays: days, currentFile: currentFile(ctx), dryRun });
				if (!dryRun) {
					ctx.ui.notify(`session-cleanup: removed ${found.length} session(s) older than ${days} days`, "info");
					return;
				}
				const names = found.slice(0, 20).map((f) => path.relative(root, f));
				const more = found.length > 20 ? `\n… and ${found.length - 20} more` : "";
				ctx.ui.notify(
					`session-cleanup (dry run): ${found.length} session(s) older than ${days} days would be removed` +
						(names.length ? `\n${names.join("\n")}${more}` : ""),
					"info",
				);
			} catch (e) {
				ctx.ui.notify(`session-cleanup failed: ${(e as Error)?.message ?? e}`, "error");
			}
		},
	});
}
