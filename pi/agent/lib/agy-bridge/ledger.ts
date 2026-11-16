import * as fs from "node:fs";
import * as path from "node:path";
import { createHash, randomUUID } from "node:crypto";

export type AgentResult = { id: string; type: string; description?: string; status: string; result?: string; error?: string; toolUses?: number; durationMs?: number; isError?: boolean; exitCode?: number | null; signal?: string };
export type Launch = { requestId: string; type: string; description?: string; state: "pending" | "launched" | "unknown" | "error"; id?: string; error?: string; result?: AgentResult };
export type Batch = { id: string; origin: string | null; createdAt: number; launches: Launch[]; noticeId: string; deliveredEntryId?: string; artifact?: string };
type Data = { version: 2; sessionId: string; cwd: string; batches: Batch[] };
export function atomicJson(filename: string, value: unknown): void {
 const temporary = `${filename}.${randomUUID()}.tmp`;
 let fd: number | undefined;
 try {
  fd = fs.openSync(temporary, "wx", 0o600); fs.writeFileSync(fd, JSON.stringify(value)); fs.fsyncSync(fd); fs.closeSync(fd); fd = undefined;
  fs.renameSync(temporary, filename);
  const dir = fs.openSync(path.dirname(filename), "r"); try { fs.fsyncSync(dir); } finally { fs.closeSync(dir); }
 } finally { if (fd !== undefined) fs.closeSync(fd); if (fs.existsSync(temporary)) fs.unlinkSync(temporary); }
}
export class Ledger {
 readonly directory: string;
 private data: Data;
 private committed: Data;
 private locked = false;
 constructor(root: string, sessionId: string, cwd: string, private generation: string) {
  const scope = createHash("sha256").update(`${sessionId}\0${cwd}`).digest("hex");
  this.directory = path.join(root, "agy-bridge", scope);
  const filename = path.join(this.directory, "ledger.json");
  if (fs.existsSync(filename)) {
   this.data = JSON.parse(fs.readFileSync(filename, "utf8"));
   if (this.data.version !== 2 || this.data.sessionId !== sessionId || this.data.cwd !== cwd || !Array.isArray(this.data.batches)) throw new Error("Invalid scoped agy completion ledger");
  } else this.data = { version: 2, sessionId, cwd, batches: [] };
  this.committed = structuredClone(this.data);
 }
 private write() {
  try {
  fs.mkdirSync(this.directory, { recursive: true, mode: 0o700 });
  if (!this.locked) {
   const fd = fs.openSync(path.join(this.directory, "owner.lock"), "wx", 0o600);
   try { fs.writeFileSync(fd, JSON.stringify({ generation: this.generation, pid: process.pid })); fs.fsyncSync(fd); } finally { fs.closeSync(fd); }
   this.locked = true;
  }
   atomicJson(path.join(this.directory, "ledger.json"), this.data); this.committed = structuredClone(this.data);
  } catch (error) { this.data = structuredClone(this.committed); throw error; }
 }
 acquire(): void { if (!this.locked) this.write(); }
 batches(): Batch[] { return structuredClone(this.data.batches); }
 begin(id: string, origin: string | null, tasks: any[]): Batch {
  const existing = this.data.batches.find(batch => batch.id === id);
  if (existing) return structuredClone(existing);
  const batch: Batch = { id, origin, createdAt: Date.now(), noticeId: randomUUID(), launches: tasks.map((task, i) => ({ requestId: `${id}:${i}`, type: task.type, description: task.description, state: "pending" })) };
  this.data.batches.push(batch); this.write(); return structuredClone(batch);
 }
 launch(batchId: string, requestId: string, change: Partial<Launch>) {
  const launch = this.data.batches.find(batch => batch.id === batchId)?.launches.find(value => value.requestId === requestId);
  if (!launch) throw new Error("Missing durable launch reservation");
  Object.assign(launch, change); this.write();
 }
 owned(id: string, branch: Array<{ id: string }>): boolean {
  return this.data.batches.some(batch => this.eligible(batch, branch) && batch.launches.some(launch => launch.id === id));
 }
 eligible(batch: Batch, branch: Array<{ id: string }>): boolean { return batch.origin === null || branch.some(entry => entry.id === batch.origin); }
 result(id: string): AgentResult | undefined {
  const value = this.data.batches.flatMap(batch => batch.launches).find(launch => launch.id === id)?.result;
  return value && structuredClone(value);
 }
 capture(raw: any, fallback: string): boolean {
  const id = String(raw?.id ?? "");
  const launch = this.data.batches.flatMap(batch => batch.launches).find(value => value.id === id);
  if (!launch) return false;
  if (launch.result) return true;
  const result: AgentResult = { id, type: launch.type, description: raw?.description ?? launch.description, status: typeof raw?.status === "string" ? raw.status : fallback };
  for (const key of ["result", "error"]) if (typeof raw?.[key] === "string") (result as any)[key] = raw[key];
  for (const key of ["toolUses", "durationMs"]) if (typeof raw?.[key] === "number" && Number.isFinite(raw[key])) (result as any)[key] = raw[key];
  if (typeof raw?.isError === "boolean") result.isError = raw.isError;
  if (raw?.exitCode === null || Number.isInteger(raw?.exitCode)) result.exitCode = raw.exitCode;
  if (typeof raw?.signal === "string") result.signal = raw.signal;
  launch.result = result;
  // Commit raw completion before the caller may suppress native Pi notification.
  this.write(); return true;
 }
 reconcile(entries: any[]): void {
  let changed = false;
  for (const batch of this.data.batches) {
   if (batch.deliveredEntryId) continue;
   const entry = entries.find(entry => entry.type === "custom_message" && entry.customType === "agy-subagent-result" && entry.details?.noticeId === batch.noticeId);
   if (entry) { batch.deliveredEntryId = entry.id; changed = true; }
  }
  if (changed) this.write();
 }
 pending(branch: any[]): Batch[] {
  return this.batches().filter(batch => this.eligible(batch, branch) && !batch.deliveredEntryId && batch.launches.length && batch.launches.every(launch => launch.result || launch.state === "error"));
 }
 notice(batchId: string): string {
  const batch = this.data.batches.find(batch => batch.id === batchId);
  if (!batch) throw new Error("Unknown completion batch");
  const text = batch.launches.map(launch => {
   const result = launch.result;
   return `### Subagent ${launch.type} (${launch.id ?? launch.requestId}; status: ${result?.status ?? launch.state})\n${result?.error ? `Error: ${result.error}\n` : ""}${result?.isError || (result?.exitCode !== undefined && result.exitCode !== null && result.exitCode !== 0) || result?.signal ? "Structured failure recorded\n" : ""}${result?.result ?? result?.error ?? launch.error ?? "Outcome unknown"}`;
  }).join("\n\n---\n\n");
  if (text.length <= 24000) return text;
  // Scoped, durable artifact: no argv clipping or deletion of pending raw results.
  const filename = path.join(this.directory, `${createHash("sha256").update(batch.id).digest("hex")}.md`);
  fs.mkdirSync(this.directory, { recursive: true, mode: 0o700 }); fs.writeFileSync(filename, text, { mode: 0o600 });
  batch.artifact = filename; this.write();
  return text.slice(0, 12000) + `\n\n[Preview only. Full verbatim completion: read_file ${filename}]`;
 }
 prune(): void {
  const removable = this.data.batches.filter(batch => batch.deliveredEntryId && batch.createdAt < Date.now() - 7 * 86400000);
  if (!removable.length) return;
  this.data.batches = this.data.batches.filter(batch => !removable.includes(batch)); this.write();
  for (const batch of removable) if (batch.artifact) fs.rmSync(batch.artifact, { force: true });
 }
 dispose(): void {
  if (!this.locked) return;
  const filename = path.join(this.directory, "owner.lock");
  const data = JSON.parse(fs.readFileSync(filename, "utf8"));
  if (data.generation !== this.generation) throw new Error("Completion ledger lock ownership changed");
  fs.unlinkSync(filename); this.locked = false;
 }
}
