import { spawn, type ChildProcess } from "node:child_process";
import * as fs from "node:fs";
import { digestDescriptor, nativePath, type Checkpoint } from "./history.ts";
import { zeroUsage } from "./ownership.ts";
import type { Model, SimpleStreamOptions, JsonObject } from "@earendil-works/pi-ai";

export type NativeBatch = {
 id: string; calls: Array<{ name: string; args: JsonObject }>; results: any[];
 correlation: "batch-only"; operationalOutcome: "unknown";
 nativeOutcome: "unknown" | "error" | "incomplete"; complete: boolean;
};
export type NativeStep = { thinking: string; text: string; batch: NativeBatch };
type Setup = { binary: string; cwd: string; prompt: string; model: Model<any>; effort: string; checkpoint: Checkpoint; env: Record<string, string>; options?: SimpleStreamOptions };
export class Runner {
 child?: ChildProcess;
 exited = false;
 ended = false;
 aborted = false;
 error?: string;
 conversationId?: string;
 offset: number;
 steps: NativeStep[] = [];
 batches = new Map<string, NativeBatch>();
 finalText = "";
 finalThinking = "";
 terminal = false;
 usage = zeroUsage();
 rawUsage?: JsonObject;
 private originalOffset: number;
 private originalDigest?: string;
 private verifiedOffset: number;
 private verifiedDigest?: string;
 private inode?: number;
 phase = "starting";
 private filename?: string;
 private seenInput = false;
 private fresh: boolean;
 private activeBatch?: NativeBatch;
 private batchSequence = 0;
 private waiters = new Set<() => void>();
 private tail?: ReturnType<typeof setInterval>;
 private escalation?: ReturnType<typeof setTimeout>;
 private abortListener?: () => void;
 private stdout = "";
 private stderr = "";
 private queue: Promise<void> = Promise.resolve();
 private exitResolve!: () => void;
 readonly exit = new Promise<void>(resolve => { this.exitResolve = resolve; });
 constructor(readonly id: string, private setup: Setup, private update: () => void) {
  this.conversationId = setup.checkpoint.conversationId;
  this.offset = setup.checkpoint.offset ?? 0;
  this.originalOffset = this.offset; this.originalDigest = setup.checkpoint.nativeDigest;
  this.verifiedOffset = this.offset; this.verifiedDigest = setup.checkpoint.nativeDigest; this.inode = setup.checkpoint.inode;
  this.fresh = !this.conversationId;
  if (this.conversationId) this.filename = nativePath(this.conversationId);
 }
 async start(): Promise<void> {
  try { await this.startProcess(); } catch (error) {
   this.error ??= error instanceof Error ? error.message : String(error);
   if (!this.child?.pid) { this.exited = true; this.ended = true; this.cleanupListeners(); this.exitResolve(); this.wake(); }
   else this.terminate();
   throw error;
  }
 }
 private async startProcess(): Promise<void> {
  if (this.setup.options?.signal?.aborted) { this.aborted = true; this.exited = true; this.ended = true; this.exitResolve(); return; }
  const args = ["-p", this.setup.prompt, "--output-format", "stream-json", "--print-timeout", "0", "--dangerously-skip-permissions", "--model", this.setup.model.id];
  if (!/^gpt-oss-.*-(low|medium|high|xhigh|max)$|orchestrator/i.test(this.setup.model.id)) args.push("--effort", this.setup.effort);
  if (this.conversationId) args.push("--conversation", this.conversationId);
  const env = { ...process.env, ...this.setup.options?.env, ...this.setup.env };
  if (Buffer.byteLength(JSON.stringify(env)) + Buffer.byteLength(this.setup.prompt) > 192 * 1024) throw new Error("agy argv/environment exceeds safe transport budget; nothing sent");
  const child = this.child = spawn(this.setup.binary, args, { cwd: this.setup.cwd, env, detached: process.platform !== "win32", stdio: ["ignore", "pipe", "pipe"] });
  this.abortListener = () => this.cancel();
  this.setup.options?.signal?.addEventListener("abort", this.abortListener, { once: true });
  child.stdout!.setEncoding("utf8");
  child.stdout!.on("data", (chunk: string) => {
   this.stdout += chunk;
   if (Buffer.byteLength(this.stdout) > 8 * 1024 * 1024) { this.fail("Native stdout frame exceeds 8 MiB"); return; }
   let nl: number;
   while ((nl = this.stdout.indexOf("\n")) >= 0) {
    const line = this.stdout.slice(0, nl); this.stdout = this.stdout.slice(nl + 1);
    if (line.trim()) this.enqueue(line);
   }
  });
  child.stderr!.setEncoding("utf8"); child.stderr!.on("data", (chunk: string) => { this.stderr = (this.stderr + chunk).slice(-32768); });
  child.on("error", error => this.fail(error.message));
  child.on("close", (code, signal) => {
   // close, not kill()/signal delivery, confirms this owned process has exited.
   this.exited = true; clearTimeout(this.escalation); clearInterval(this.tail);
   if (this.stdout.trim()) this.enqueue(this.stdout);
   this.queue = this.queue.then(() => {
    this.drain();
    if (!this.aborted && (code !== 0 || signal)) this.error ??= `agy exited ${signal ? `by ${signal}` : `with code ${code}`}\n${this.stderr.trim()}`;
    if (!this.aborted && !this.error && !this.terminal) this.error = "Incomplete native stream: missing terminal result";
    if (!this.aborted && !this.error && !this.seenInput) this.error = "Native transcript did not verify this submitted input; use /agy-new";
    this.finishBatch(this.error || this.aborted ? "incomplete" : undefined);
    this.ended = true; this.cleanupListeners(); this.wake(); this.exitResolve();
   }).catch(error => { this.error = String(error); this.ended = true; this.cleanupListeners(); this.wake(); this.exitResolve(); });
  });
  await new Promise<void>((resolve, reject) => { child.once("spawn", resolve); child.once("error", reject); });
  this.tail = setInterval(() => { this.drain(); this.update(); }, 80);
  if (this.setup.options?.signal?.aborted) this.cancel();
 }
 private enqueue(line: string) {
  this.queue = this.queue.then(async () => {
   let event: any;
   try { event = JSON.parse(line); } catch { this.fail("Malformed native stream-json frame"); return; }
   if (!event || typeof event !== "object" || typeof event.event !== "string") { this.fail("Invalid native event envelope"); return; }
   await this.setup.options?.onProviderStreamEvent?.(event, this.setup.model);
   if (this.aborted || this.error) return;
   const result = event.result;
   const id = event.conversation_id ?? event.step_update?.conversation_id ?? result?.conversation_id;
   if (id !== undefined) this.identify(id, event.event);
   this.drain();
   if (event.event === "init") this.phase = "thinking";
   if (event.event === "result") {
    if (this.terminal) { this.fail("Duplicate native terminal result"); return; }
    if (!result || typeof result !== "object" || !this.conversationId || result.conversation_id !== this.conversationId) { this.fail("Invalid native terminal result"); return; }
    this.terminal = true;
    if (result.usage !== undefined) {
     if (!result.usage || typeof result.usage !== "object" || Array.isArray(result.usage)) throw new Error("Invalid native terminal usage");
     const mapping = { input_tokens: "input", output_tokens: "output", cache_read_tokens: "cacheRead", total_tokens: "totalTokens" } as const;
     for (const [native, sdk] of Object.entries(mapping)) {
      const value = result.usage[native];
      if (value !== undefined) { if (!Number.isSafeInteger(value) || value < 0) throw new Error("Invalid native token counter: " + native); (this.usage as any)[sdk] = value; }
     }
     if (result.usage.thinking_tokens !== undefined && (!Number.isSafeInteger(result.usage.thinking_tokens) || result.usage.thinking_tokens < 0)) throw new Error("Invalid native thinking token counter");
     this.rawUsage = result.usage;
    }
    if (result.status !== "SUCCESS") this.fail(String(result.error ?? result.response ?? `Unknown native result status: ${result.status}`));
    else if (typeof result.response !== "string") this.fail("Native SUCCESS result has no string response");
    else this.finalText = result.response;
   }
   this.wake();
  }).catch(error => this.fail(error instanceof Error ? error.message : String(error)));
 }
 private identify(value: unknown, event: string) {
  if (typeof value !== "string") throw new Error("Invalid native conversation identifier");
  const filename = nativePath(value);
  if (this.conversationId && this.conversationId !== value) throw new Error("Native conversation changed unexpectedly; refusing adoption/replay; use /agy-new");
  if (!this.conversationId) {
   if (event !== "init" || !this.fresh) throw new Error("Native conversation was not established by init; refusing adoption");
   this.conversationId = value; this.filename = filename;
  }
 }
 private record(rec: any) {
  if (this.aborted || this.error) return;
  if (!rec || typeof rec !== "object" || typeof rec.type !== "string") throw new Error("Invalid native transcript record");
  if (rec.type === "USER_INPUT") {
   // Recorded agy 1.5.9 USER_EXPLICIT records wrap -p input, then append
   // native metadata/settings. Match the entire submitted payload, never a substring.
   const prefix = `<USER_REQUEST>\n${this.setup.prompt}\n</USER_REQUEST>`;
   const suffix = typeof rec.content === "string" && rec.content.startsWith(prefix) ? rec.content.slice(prefix.length) : undefined;
   const metadata = /^(?:\n<(ADDITIONAL_METADATA|USER_SETTINGS_CHANGE)>\n[\s\S]*?\n<\/\1>)*$/;
   if (this.seenInput || rec.source !== "USER_EXPLICIT" || rec.status !== "DONE" || suffix === undefined || !metadata.test(suffix)) throw new Error("Native transcript input does not match this turn (or contains another turn); use /agy-new");
   this.seenInput = true; return;
  }
  if (rec.source === "SYSTEM" && rec.type === "ERROR_MESSAGE") {
   this.phase = "native error/retry (outcome unconfirmed)"; this.wake(); return;
  }
  if (rec.source !== "MODEL") return;
  if (!this.seenInput) throw new Error("Native model records preceded verified current input; refusing replay");
  if (rec.type === "PLANNER_RESPONSE") {
   this.finishBatch();
   if (rec.status === "ERROR" || rec.error) { this.fail(String(rec.error ?? rec.content ?? "Native planner failed")); return; }
   const thinking = typeof rec.thinking === "string" ? rec.thinking : "";
   const text = typeof rec.content === "string" ? rec.content : "";
   if (Array.isArray(rec.tool_calls) && rec.tool_calls.length) {
    const calls = rec.tool_calls.map((call: any) => {
     if (!call || typeof call.name !== "string" || !call.args || typeof call.args !== "object" || Array.isArray(call.args)) throw new Error("Malformed native planner call");
     return { name: call.name, args: call.args };
    });
    const batch: NativeBatch = { id: `${this.id}:${this.batchSequence++}`, calls, results: [], correlation: "batch-only", operationalOutcome: "unknown", nativeOutcome: "unknown", complete: false };
    this.batches.set(batch.id, batch); this.activeBatch = batch;
    this.steps.push({ thinking, text, batch }); this.phase = "native tools (batch-only correlation)";
   } else { this.finalThinking = thinking; this.phase = "responding"; }
   this.wake();
  } else if (rec.type === "GENERIC") {
   if (!this.activeBatch) throw new Error("Unassociated native result outside a planner batch");
   // No call IDs exist in this format. Keep ordered calls and unassociated records.
   this.activeBatch.results.push(rec);
   if (rec.status === "ERROR" || rec.error) this.activeBatch.nativeOutcome = "error";
   this.wake();
  }
 }
 private finishBatch(outcome?: "incomplete") {
  if (!this.activeBatch) return;
  this.activeBatch.complete = true;
  if (outcome) this.activeBatch.nativeOutcome = outcome;
  this.activeBatch = undefined; this.wake();
 }
 private drain() {
  if (!this.filename || this.aborted || this.error) return;
  let fd: number | undefined;
  try {
   fd = fs.openSync(this.filename, "r"); const stat = fs.fstatSync(fd);
   if (stat.size < this.offset) throw new Error("Native transcript truncated while running");
   this.verifyDescriptor(fd);
   while (this.offset < stat.size) {
    const buffer = Buffer.alloc(Math.min(stat.size - this.offset, 8 * 1024 * 1024));
    const count = fs.readSync(fd, buffer, 0, buffer.length, this.offset);
    const nl = buffer.subarray(0, count).lastIndexOf(10);
    if (nl < 0) { if (buffer.length === 8 * 1024 * 1024) throw new Error("Native transcript line exceeds 8 MiB"); break; }
    this.offset += nl + 1;
    for (const line of buffer.subarray(0, nl + 1).toString("utf8").split("\n")) if (line.trim()) this.record(JSON.parse(line));
   }
   if (!this.error) { const value = digestDescriptor(fd, this.offset, this.guards()); this.verifiedOffset = this.offset; this.verifiedDigest = value.digest; this.inode = value.inode; }
  } catch (error: any) { if (error.code !== "ENOENT") this.fail(error.message); }
  finally { if (fd !== undefined) fs.closeSync(fd); }
 }
 private fail(message: string) { this.error ??= message; this.terminate(); this.wake(); }
 cancel() { this.aborted = true; this.terminate(); this.wake(); }
 private signal(signal: NodeJS.Signals) {
  if (!this.child?.pid || this.exited) return;
  try { if (process.platform !== "win32") process.kill(-this.child.pid, signal); else this.child.kill(signal); }
  catch (error: any) { if (error.code !== "ESRCH") this.error ??= `Failed to send ${signal}: ${error.message}`; }
 }
 private terminate() {
  if (this.exited || this.escalation) return;
  this.signal("SIGTERM");
  this.escalation = setTimeout(() => { this.signal("SIGKILL"); }, 2000);
 }
 async stopAndConfirm(): Promise<void> {
  if (!this.exited) this.terminate();
  await new Promise<void>((resolve, reject) => {
   const timer = setTimeout(() => reject(new Error("Owned agy process exit is unconfirmed; refusing a new runner")), 8000);
   this.exit.then(() => { clearTimeout(timer); resolve(); }, reject);
  });
 }
 private cleanupListeners() { clearInterval(this.tail); clearTimeout(this.escalation); if (this.abortListener) this.setup.options?.signal?.removeEventListener("abort", this.abortListener); }
 private wake() { for (const resolve of this.waiters) resolve(); this.waiters.clear(); this.update(); }
 async changed(signal?: AbortSignal): Promise<void> {
  if (signal?.aborted) throw new Error("Cancelled");
  await new Promise<void>((resolve, reject) => {
   const done = () => { signal?.removeEventListener("abort", abort); this.waiters.delete(done); resolve(); };
   const abort = () => { this.waiters.delete(done); reject(new Error("Cancelled")); };
   this.waiters.add(done); signal?.addEventListener("abort", abort, { once: true });
  });
 }
 private guards() {
  return [{ bytes: this.originalOffset, digest: this.originalDigest }, { bytes: this.verifiedOffset, digest: this.verifiedDigest }].filter((guard): guard is { bytes: number; digest: string } => Boolean(guard.digest));
 }
 private verifyDescriptor(fd: number) {
  const stat = fs.fstatSync(fd);
  if (this.inode !== undefined && stat.ino !== this.inode) throw new Error("Native transcript inode changed during owned turn");
  digestDescriptor(fd, Math.max(this.originalOffset, this.verifiedOffset), this.guards());
  this.inode ??= stat.ino;
 }
 checkpoint(): Pick<Checkpoint, "conversationId" | "offset" | "inode" | "nativeDigest"> {
  if (!this.exited || !this.ended || !this.terminal || this.aborted || this.error || !this.filename) throw new Error("No successful native checkpoint");
  const fd = fs.openSync(this.filename, "r");
  try {
   const stat = fs.fstatSync(fd); this.verifyDescriptor(fd);
   if (stat.size !== this.offset) throw new Error("Native transcript ended with an incomplete line; use /agy-new");
   const value = digestDescriptor(fd, this.offset, this.guards());
   return { conversationId: this.conversationId, offset: this.offset, inode: value.inode, nativeDigest: value.digest };
  } finally { fs.closeSync(fd); }
 }
}
