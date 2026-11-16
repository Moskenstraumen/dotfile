import * as net from "node:net";
import * as fs from "node:fs";
import * as path from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Frames, MAX_FRAME, MAX_DEADLINE_MS, validate } from "./protocol.mjs";
import { Ledger, type AgentResult } from "./ledger.ts";
import { token } from "./ownership.ts";

function message(error: unknown) { return error instanceof Error ? error.message : String(error); }
export class Harness {
 private unsubscribers: Array<() => void> = [];
 private waiters = new Set<() => void>();
 private late = new Set<() => void>();
 private syncAgents = new Map<string, Set<string>>();
 private turnSignals = new Map<string, AbortController>();
 constructor(private pi: ExtensionAPI, readonly ledger: Ledger, private context: () => ExtensionContext, private notify: (error: string) => void, private completed: () => void) {
  this.unsubscribers.push(pi.events.on("subagents:completed", raw => this.capture(raw, "completed")), pi.events.on("subagents:failed", raw => this.capture(raw, "error")));
 }
 private capture(raw: any, status: string) {
  try {
   if (!this.ledger.capture(raw, status)) return;
   this.pi.events.emit("subagents:rpc:consume", { requestId: `agy-consume-${token()}`, agentId: raw.id });
   for (const resolve of this.waiters) resolve(); this.waiters.clear(); queueMicrotask(this.completed);
  } catch (error) { this.notify(`Completion was not durably captured/suppressed: ${message(error)}`); }
 }
 private manager() { return (globalThis as any)[Symbol.for("pi-subagents:manager")]; }
 recover() {
  for (const batch of this.ledger.batches()) for (const launch of batch.launches) {
   if (!launch.id || launch.result) continue;
   const live = this.manager()?.getRecord?.(launch.id);
   if (live && ["completed", "error", "stopped", "aborted"].includes(live.status)) this.capture({ ...live, durationMs: live.completedAt && live.startedAt ? live.completedAt - live.startedAt : undefined }, live.status);
  }
 }
 private rpc(channel: string, payload: any, signal: AbortSignal, deadline: number, lateReply?: (raw: any) => void): Promise<any> {
  if (this.late.size >= 128) throw new Error("Too many unresolved launch outcomes; no new launches admitted");
  return new Promise((resolve, reject) => {
   const requestId = payload.requestId ?? `agy-rpc-${token()}`;
   let settled = false, responded = false, emitted = false;
   const cleanup = () => { clearTimeout(timer); signal.removeEventListener("abort", abort); };
   const remove = () => { unsubscribe(); this.late.delete(remove); };
   const finish = (error?: Error, value?: any) => { if (settled) return; settled = true; cleanup(); if (!error || !lateReply || responded || !emitted) remove(); else this.late.add(remove); error ? reject(error) : resolve(value); };
   const abort = () => finish(new Error(`${channel} cancelled; operational outcome unknown`));
   const unsubscribe = this.pi.events.on(`${channel}:reply:${requestId}`, (raw: any) => {
    if (settled) { try { lateReply?.(raw); } catch (error) { this.notify(message(error)); } remove(); return; }
    responded = true;
    if (raw?.success === true) finish(undefined, raw.data);
    else { lateReply?.(raw); finish(new Error(raw?.error || `${channel} failed`)); }
   });
   const timer = setTimeout(() => finish(new Error(`${channel} deadline exceeded; operational outcome unknown`)), Math.max(1, deadline - Date.now()));
   signal.addEventListener("abort", abort, { once: true });
   if (signal.aborted) { abort(); return; }
   try { emitted = true; this.pi.events.emit(channel, { ...payload, requestId }); } catch (error) { finish(new Error(message(error))); }
  });
 }
 private allowed(id: string) {
  if (!this.ledger.owned(id, this.context().sessionManager.getBranch())) throw new Error("Unknown agent or agent belongs to another branch");
 }
 async wait(ids: string[], signal: AbortSignal, deadline: number): Promise<{ results: AgentResult[]; pending: Array<{ id: string; status: string }>; timedOut: boolean }> {
  for (const id of ids) this.allowed(id);
  while (true) {
   const values = ids.map(id => this.ledger.result(id));
   if (signal.aborted) throw new Error("Wait cancelled; results remain pending");
   if (values.every(Boolean) || Date.now() >= deadline) return { results: values.filter(Boolean) as AgentResult[], pending: ids.filter((_, i) => !values[i]).map(id => ({ id, status: this.manager()?.getRecord?.(id)?.status ?? "unknown" })), timedOut: !values.every(Boolean) };
   await new Promise<void>((resolve, reject) => {
    const cleanup = () => { clearTimeout(timer); signal.removeEventListener("abort", abort); this.waiters.delete(done); };
    const done = () => { cleanup(); resolve(); };
    const abort = () => { cleanup(); reject(new Error("Wait cancelled; results remain pending")); };
    const timer = setTimeout(done, Math.max(1, deadline - Date.now()));
    this.waiters.add(done); signal.addEventListener("abort", abort, { once: true });
   });
  }
 }
 async handle(turnId: string, requestId: string, method: string, params: any, signal: AbortSignal, deadline: number): Promise<any> {
  validate(method, params);
  const ctx = this.context();
  if (method === "subagent_spawn") {
   const id = `${turnId}:${requestId}`;
   const existing = this.ledger.batches().find(batch => batch.id === id);
   const unresolved = this.ledger.batches().filter(batch => this.ledger.eligible(batch, ctx.sessionManager.getBranch())).flatMap(batch => batch.launches).filter(launch => !launch.id && ["pending", "unknown"].includes(launch.state));
   if (!existing && unresolved.length) { const error: any = new Error("Unresolved prior launch outcomes block new launches; inspect status, do not respawn"); error.details = { launchStates: unresolved }; throw error; }
   const batch = this.ledger.begin(id, ctx.sessionManager.getLeafId(), params.tasks);
   // Retried MCP request IDs return their durable reservation, never emit another launch.
   const owningAbort = this.turnSignals.get(turnId) ?? new AbortController(); this.turnSignals.set(turnId, owningAbort);
   if (!existing) for (const launch of batch.launches) {
    if (signal.aborted || Date.now() >= deadline) { this.ledger.launch(id, launch.requestId, { state: "error", error: "Not launched: request cancelled/deadline" }); continue; }
    const task = params.tasks[batch.launches.indexOf(launch)];
    const accept = (raw: any) => {
     if (raw?.success !== true || typeof raw?.data?.id !== "string") { this.ledger.launch(id, launch.requestId, { state: "error", error: raw?.error ?? "Invalid launch reply" }); return; }
     this.ledger.launch(id, launch.requestId, { state: "launched", id: raw.data.id });
     if (params.wait) { const set = this.syncAgents.get(turnId) ?? new Set<string>(); set.add(raw.data.id); this.syncAgents.set(turnId, set); }
     if (params.wait && owningAbort.signal.aborted && !this.ledger.result(raw.data.id)) this.pi.events.emit("subagents:rpc:stop", { requestId: `agy-late-stop-${token()}`, agentId: raw.data.id });
     this.recover();
    };
    // Reserve unknown before emitting: a crash/deadline is not proof no agent launched.
    this.ledger.launch(id, launch.requestId, { state: "unknown" });
    try {
     const data = await this.rpc("subagents:rpc:spawn", { requestId: launch.requestId, type: task.type, prompt: task.prompt, options: { description: task.description ?? `${task.type} task`, cwd: task.cwd ?? ctx.cwd, isBackground: true, signal: params.wait ? owningAbort.signal : undefined, onSpawned: (agentId: string) => accept({ success: true, data: { id: agentId } }) } }, signal, Math.min(deadline, Date.now() + 15000), accept);
     accept({ success: true, data });
    } catch (error) { this.ledger.launch(id, launch.requestId, { error: message(error) }); }
   }
   const current = this.ledger.batches().find(batch => batch.id === id)!;
   const spawned = current.launches.filter(launch => launch.id).map(launch => ({ id: launch.id, type: launch.type, description: launch.description }));
   if (current.launches.some(launch => launch.state !== "launched")) {
    const error: any = new Error("Partial/unresolved launch batch; inspect launchStates and do not respawn unresolved tasks"); error.details = { batchId: id, spawned, launchStates: current.launches }; throw error;
   }
   if (params.wait) return { batchId: id, spawned, ...await this.wait(spawned.map(value => value.id!), signal, Math.min(deadline, Date.now() + (params.timeoutMs ?? 30000))) };
   return { batchId: id, spawned, completionNotice: "best-effort", operationalOutcome: "launch accepted; execution pending" };
  }
  if (method === "subagent_status") {
   const ids = params.ids ?? this.ledger.batches().filter(batch => this.ledger.eligible(batch, ctx.sessionManager.getBranch())).flatMap(batch => batch.launches).filter(launch => launch.id).map(launch => launch.id);
   const agents = ids.map((id: string) => {
    this.allowed(id); const value = this.ledger.result(id) ?? this.manager()?.getRecord?.(id);
    return { id, type: value?.type, status: value?.status ?? "unknown", description: value?.description, toolUses: value?.toolUses, error: value?.error };
   });
   return { agents, launchStates: this.ledger.batches().filter(batch => this.ledger.eligible(batch, ctx.sessionManager.getBranch())).flatMap(batch => batch.launches).filter(launch => !launch.id) };
  }
  if (method === "subagent_wait") return this.wait(params.ids, signal, Math.min(deadline, Date.now() + (params.timeoutMs ?? 30000)));
  if (method === "subagent_steer" || method === "subagent_stop") {
   this.allowed(params.agentId);
   const reply = await this.rpc(method === "subagent_stop" ? "subagents:rpc:stop" : "subagents:rpc:steer", { agentId: params.agentId, message: params.message }, signal, deadline);
   return { accepted: true, operationalOutcome: "unconfirmed", reply };
  }
  if (method === "ask_user") {
   if (!ctx.hasUI || !["tui", "rpc"].includes(ctx.mode)) throw new Error("Interactive UI unavailable in this session");
   const options = { signal, timeout: Math.max(1, deadline - Date.now()) };
   let answer: string | undefined;
   if (params.options?.length) {
    const custom = "Enter a custom response…";
    answer = await ctx.ui.select(params.question, [...params.options, custom], options);
    if (answer === custom && !signal.aborted) answer = await ctx.ui.input(params.question, params.placeholder, options);
   } else answer = await ctx.ui.input(params.question, params.placeholder, options);
   if (signal.aborted) throw new Error("UI request cancelled");
   return answer === undefined ? { cancelled: true } : { cancelled: false, answer };
  }
  throw new Error(`Unknown method: ${method}`);
 }
 cancelSync(turnId: string) {
  this.turnSignals.get(turnId)?.abort();
  for (const id of this.syncAgents.get(turnId) ?? []) if (!this.ledger.result(id)) this.pi.events.emit("subagents:rpc:stop", { requestId: `agy-stop-${token()}`, agentId: id });
  this.syncAgents.delete(turnId);
 }
 forgetTurn(turnId: string) { this.syncAgents.delete(turnId); this.turnSignals.delete(turnId); }
 dispose() { for (const abort of this.turnSignals.values()) abort.abort(); this.turnSignals.clear(); for (const unsubscribe of this.unsubscribers) unsubscribe(); for (const remove of this.late) remove(); this.late.clear(); for (const resolve of this.waiters) resolve(); this.waiters.clear(); }
}
export class TurnSocket {
 readonly token = token();
 readonly filename: string;
 private server?: net.Server;
 private connections = new Set<net.Socket>();
 private aborts = new Set<AbortController>();
 private ids = new Set<string>();
 private closing = false;
 constructor(directory: string, readonly turnId: string, private harness: Harness) { this.filename = path.join(directory, "rpc.sock"); }
 async ready(): Promise<void> {
  this.server = net.createServer(conn => {
   if (this.closing || this.connections.size >= 32) { conn.destroy(); return; }
   this.connections.add(conn); const frames = new Frames(); let admitted = false;
   conn.on("close", () => this.connections.delete(conn)); conn.setTimeout(MAX_DEADLINE_MS, () => conn.destroy());
   conn.on("error", () => {});
   conn.on("data", chunk => {
    try { for (const req of frames.push(chunk)) {
     if (admitted || !req || typeof req.id !== "string" || req.id.length > 200 || req.token !== this.token || req.turnId !== this.turnId || typeof req.deadline !== "number" || !Number.isFinite(req.deadline) || req.deadline <= Date.now() || req.deadline > Date.now() + MAX_DEADLINE_MS + 1000 || this.ids.has(req.id) || this.ids.size >= 4096) throw new Error("Invalid/duplicate/expired turn-owned request");
     admitted = true; this.ids.add(req.id);
     const abort = new AbortController(); this.aborts.add(abort); conn.once("close", () => abort.abort());
     const timer = setTimeout(() => abort.abort(), req.deadline - Date.now());
     void this.harness.handle(this.turnId, req.id, req.method, req.params, abort.signal, req.deadline).then(result => reply({ id: req.id, ok: true, result }), error => reply({ id: req.id, ok: false, error: message(error), details: error.details })).finally(() => { clearTimeout(timer); this.aborts.delete(abort); });
     const reply = (value: any) => { if (conn.destroyed || this.closing) return; const frame = JSON.stringify(value) + "\n"; conn.end(Buffer.byteLength(frame) <= MAX_FRAME ? frame : JSON.stringify({ id: req.id, ok: false, error: "Bridge response exceeds frame limit; result remains durable" }) + "\n"); };
    } } catch (error) { conn.end(JSON.stringify({ id: null, ok: false, error: message(error) }) + "\n"); }
   });
  });
  await new Promise<void>((resolve, reject) => {
   this.server!.once("error", reject);
   this.server!.listen(this.filename, () => { try { fs.chmodSync(this.filename, 0o600); resolve(); } catch (error) { reject(error); } });
  });
 }
 async close(): Promise<void> {
  this.closing = true; for (const abort of this.aborts) abort.abort(); for (const conn of this.connections) conn.destroy();
  if (this.server?.listening) await new Promise<void>(resolve => this.server!.close(() => resolve()));
  if (fs.existsSync(this.filename)) fs.unlinkSync(this.filename); this.ids.clear();
 }
}
