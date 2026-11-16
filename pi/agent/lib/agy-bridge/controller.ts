import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { getAgentDir, UserMessageComponent, AssistantMessageComponent, getMarkdownTheme, type ExtensionAPI, type ExtensionContext, type ProviderModelConfig } from "@earendil-works/pi-coding-agent";
import { registerSessionResourceCleanup, type AssistantMessage, type Model, type SimpleStreamOptions, type TranscriptContext } from "@earendil-works/pi-ai";
import { Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";
import { appendAssistant, fingerprint, history, isPrefix, promptFor, STATE_ENTRY, verifyNative, type Checkpoint } from "./history.ts";
import { claim, dispatch, emptyMessage, release, ROUTE_PROBE, sharedModels, token, type Owner } from "./ownership.ts";
import { Ledger } from "./ledger.ts";
import { Harness, TurnSocket } from "./rpc.ts";
import { Runner, type NativeBatch } from "./runner.ts";

type ProviderChatModelConfig = Extract<ProviderModelConfig, { type?: "chat" }>;
const EFFORT = /^(low|medium|high|xhigh|max)$/;
const SEMANTIC_SUFFIX = /^gpt-oss-.*-(low|medium|high|xhigh|max)$|orchestrator/i;
function baseModel(id: string) { return SEMANTIC_SUFFIX.test(id) ? id : id.replace(/-(low|medium|high|xhigh|max)$/i, ""); }
function text(content: any) { return typeof content === "string" ? content : Array.isArray(content) ? content.filter(block => block.type === "text").map(block => block.text).join("\n") : ""; }
function errorText(error: unknown) { return error instanceof Error ? error.message : String(error); }
function resolveBinary() {
 if (process.env.PI_AGY_BRIDGE_BIN) return process.env.PI_AGY_BRIDGE_BIN;
 return (process.env.PATH || "").split(path.delimiter).map(directory => path.join(directory, "agy")).find(filename => { try { fs.accessSync(filename, fs.constants.X_OK); return fs.statSync(filename).isFile(); } catch { return false; } });
}
function definition(id: string, contextWindow = 1000000, maxTokens = 65536, levels = ["low", "medium", "high"]): ProviderChatModelConfig {
 const reasoning = !SEMANTIC_SUFFIX.test(id);
 return { id, name: id, reasoning, input: id.startsWith("gpt-oss-") ? ["text"] : ["text", "image"], contextWindow, maxTokens,
  cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }, thinkingLevelMap: reasoning ? { off: null, minimal: null, low: "low", medium: "medium", high: "high", xhigh: levels.includes("xhigh") ? "xhigh" : null, max: levels.includes("max") ? "max" : null } : undefined };
}
const ObserverParams = Type.Object({ summary: Type.String(), batchId: Type.String() });
type Active = { runner: Runner; socket: TurnSocket; directory: string; finished: boolean };

export class Controller implements Owner {
 readonly token = token();
 readonly generation = token();
 sessionId = "";
 disposed = false;
 private ctx?: ExtensionContext;
 private checkpoint?: Checkpoint;
 private enabled = false;
 private model = baseModel(process.env.PI_AGY_BRIDGE_MODEL?.trim() || "gemini-4-carbon");
 private effort = EFFORT.test(process.env.PI_AGY_BRIDGE_EFFORT || "") ? process.env.PI_AGY_BRIDGE_EFFORT! : "medium";
 private fallback?: Model<any>;
 private fallbackThinking?: ReturnType<ExtensionAPI["getThinkingLevel"]>;
 private syncing = false;
 private observer?: any;
 private observerExposed = false;
 private active?: Active;
 private requesting = false;
 private ledger?: Ledger;
 private harness?: Harness;
 private cleanupResource?: () => void;
 private disposal?: Promise<void>;
 private notices = new Set<string>();
 private catalog = new Map<string, ProviderChatModelConfig>([
  definition("gemini-4-carbon"), definition("gemini-4-argon"), definition("gemini-4-hydrogen", 1000000, 65536, ["low", "medium", "high", "xhigh"]), definition("gemini-3.8-flash"),
  definition("claude-opus-5-5", 200000, 64000), definition("claude-sonnet-5-5", 200000, 64000), definition("gemini-pro-orchestrator"), definition("gemini-pro-orchestrator-argon"), definition("gpt-oss-120b-medium", 128000, 32768),
 ].map(model => [model.id, model]));
 constructor(private pi: ExtensionAPI, private binary: string) {
  if (!this.catalog.has(this.model)) this.catalog.set(this.model, definition(this.model));
  this.provider(); this.register();
 }
 private provider() { this.pi.registerProvider("agy", { api: "agy-cli", apiKey: "agy-local", baseUrl: "local://agy-cli", models: sharedModels([...this.catalog.values()]), streamSimple: dispatch }); }
 private requireContext(): ExtensionContext { if (this.disposed || !this.ctx) throw new Error("agy session owner is not active"); return this.ctx; }
 private initialize(ctx: ExtensionContext) {
  if (this.disposed) throw new Error("Stale agy controller");
  const id = ctx.sessionManager.getSessionId();
  if (this.sessionId && this.sessionId !== id) throw new Error("Pi session changed without disposing its agy controller");
  this.ctx = ctx;
  if (this.sessionId) return;
  this.sessionId = id; claim(this);
  this.cleanupResource = registerSessionResourceCleanup(sessionId => { if (sessionId === this.sessionId) void this.dispose().catch(error => this.warn(errorText(error))); });
  this.ledger = new Ledger(getAgentDir(), id, ctx.cwd, this.generation);
  this.harness = new Harness(this.pi, this.ledger, () => this.requireContext(), error => this.warn(error), () => this.flush());
  for (const entry of ctx.sessionManager.getBranch()) {
   if (entry.type !== "custom") continue;
   if (entry.customType === STATE_ENTRY) {
    const data = entry.data as any;
    if (data?.version === 2 && Array.isArray(data.history) && data.history.every((value: any) => typeof value === "string" && /^[a-f0-9]{64}$/.test(value))) {
     this.checkpoint = structuredClone(data);
     if (data.sessionId !== id) this.invalidate("Forked/copied Pi context requires /agy-new");
    } else this.invalidate("Invalid checkpoint requires /agy-new");
   } else if (entry.customType === "agy-bridge:state" && (entry.data as any)?.conversationId && !this.checkpoint) this.invalidate("Legacy native mapping is unverified; use /agy-new");
  }
  this.commitTerminal();
  if (this.checkpoint && this.checkpoint.outcome !== "success" && !this.checkpoint.needsNew) this.invalidate("Prior native turn did not finish successfully; use /agy-new");
  this.harness.recover(); this.ledger.reconcile(ctx.sessionManager.getEntries());
 }
 private commitTerminal() {
  const cp = this.checkpoint;
  if (!cp?.terminalFingerprint || cp.outcome !== "running" || !this.ctx) return;
  const branch = this.ctx.sessionManager.getBranch();
  if (cp.boundary !== null && !branch.some(entry => entry.id === cp.boundary)) return;
  const entry = branch.find(entry => entry.type === "message" && entry.message.role === "assistant" && entry.message.stopReason === "stop" && fingerprint(entry.message) === cp.terminalFingerprint);
  if (!entry) return;
  cp.outcome = "success"; cp.committedEntryId = entry.id; this.persist();
 }
 private warn(message: string) { if (!this.disposed) this.ctx?.ui.notify(message, "warning"); }
 private invalidate(reason: string) {
  this.checkpoint ??= { version: 2, sessionId: this.sessionId, boundary: this.ctx?.sessionManager.getLeafId() ?? null, history: [], outcome: "unknown" };
  this.checkpoint.needsNew = reason;
 }
 private persist() {
  if (this.disposed || !this.checkpoint) return;
  this.pi.appendEntry(STATE_ENTRY, structuredClone(this.checkpoint));
 }
 private tools(on: boolean) {
  if (this.observer && on !== this.observerExposed) {
   this.pi.registerTool({ ...this.observer, exposure: on ? "model-only" : "hidden" }); this.observerExposed = on;
  }
  const current = this.pi.getActiveTools();
  const next = on ? [...new Set([...current, "agy_batch"])] : current.filter(name => name !== "agy_batch");
  if (next.length !== current.length || next.some((name, i) => name !== current[i])) this.pi.setActiveTools(next);
 }
 private async select(on: boolean, ctx: ExtensionContext) {
  this.initialize(ctx);
  if (!on && this.active && !this.active.runner.exited) await this.stop();
  this.syncing = true;
  try {
   if (on) {
    if (ctx.model?.provider !== "agy") { this.fallback = ctx.model; this.fallbackThinking = this.pi.getThinkingLevel(); }
    if (!this.catalog.has(this.model)) { this.catalog.set(this.model, definition(this.model)); this.provider(); }
    const model = ctx.modelRegistry.find("agy", this.model);
    if (!model || !await this.pi.setModel(model)) throw new Error("Unable to select agy model");
    this.pi.setThinkingLevel(this.effort as any); const actual = this.pi.getThinkingLevel(); if (EFFORT.test(actual)) this.effort = actual;
   } else if (ctx.model?.provider === "agy") {
    const settings = this.pi.getSettings();
    const model = this.fallback ?? (settings.defaultProvider && settings.defaultProvider !== "agy" && settings.defaultModel ? ctx.modelRegistry.find(settings.defaultProvider, settings.defaultModel) : undefined);
    if (!model || !await this.pi.setModel(model)) throw new Error("No fallback model; select one with /model");
    if (this.fallbackThinking) this.pi.setThinkingLevel(this.fallbackThinking);
   }
   this.enabled = on; this.tools(on);
   this.pi.appendEntry("agy-bridge:mode-v2", { enabled: on, model: this.model, effort: this.effort, fallbackProvider: this.fallback?.provider, fallbackModel: this.fallback?.id });
  } finally { this.syncing = false; }
 }
 private mentionsRunning(value: string): boolean {
  const handle = /^@([a-zA-Z0-9._-]+)\s/.exec(value.trim())?.[1]?.toLowerCase(); if (!handle) return false;
  const manager = (globalThis as any)[Symbol.for("pi-subagents:manager")];
  const resolved = manager?.resolveMention?.(handle);
  const record = resolved?.kind === "live" ? resolved.record : manager?.getRecord?.(handle);
  if (record && ["running", "queued"].includes(record.status)) return true;
  return this.ledger?.batches().filter(batch => this.ledger!.eligible(batch, this.requireContext().sessionManager.getBranch())).flatMap(batch => batch.launches).some(launch => {
   const agent = launch.id && manager?.getRecord?.(launch.id);
   return agent && ["running", "queued"].includes(agent.status) && [agent.handle, agent.alias].some(name => name?.toLowerCase() === handle);
  }) ?? false;
 }
 private status() {
  const ctx = this.ctx;
  if (this.disposed || !ctx?.hasUI) return;
  const runner = this.active?.runner;
  ctx.ui.setWidget("agy-live", runner && !runner.ended ? [`agy · ${runner.conversationId?.slice(0, 8) ?? "new"} · ${runner.phase} · token/cost usage unknown`] : undefined);
 }
 private async cleanupActive(active: Active) {
  // Retain ownership and artifacts until this exact subprocess is confirmed exited.
  if (!active.runner.exited) await active.runner.stopAndConfirm();
  await active.runner.exit; await active.socket.close();
  this.harness?.forgetTurn(active.runner.id); fs.rmSync(active.directory, { recursive: true, force: true });
  if (this.active === active) this.active = undefined; this.status();
 }
 async request(model: Model<any>, context: TranscriptContext, options: SimpleStreamOptions | undefined, start: () => void): Promise<AssistantMessage> {
  const ctx = this.requireContext(), output = emptyMessage(model);
  if (this.requesting) throw new Error("Overlapping agy model requests are not admitted");
  this.requesting = true;
  let additionalAbort: (() => void) | undefined;
  try {
   if (this.checkpoint?.needsNew) throw new Error(this.checkpoint.needsNew);
   const current = history(context), cp = this.checkpoint;
   if (cp && (!isPrefix(cp.history, current) || (cp.boundary !== null && !ctx.sessionManager.getBranch().some(entry => entry.id === cp.boundary)))) throw new Error("Pi effective context/branch differs from native checkpoint; use /agy-new");
   const continuing = this.active && !this.active.finished;
   if (continuing) {
    if (!cp || current.length !== cp.history.length) throw new Error("New Pi input/context during a native observer continuation is unsupported; use followUp or /agy-new");
   } else {
    if (this.active) await this.cleanupActive(this.active);
    if (cp?.conversationId) {
     if (cp.outcome !== "success") throw new Error("Unverified native continuation; use /agy-new");
     verifyNative(cp);
     const delta = context.messages.slice(cp.history.length);
     if (!delta.length || delta.some(message => message.role !== "user")) throw new Error("Non-user transcript change requires /agy-new");
    }
    this.ledger!.acquire();
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), "agy-")); fs.chmodSync(directory, 0o700);
    const id = token(), socket = new TurnSocket(directory, id, this.harness!);
    try {
     const seed = !cp?.conversationId;
     const prompt = promptFor(seed ? context.messages : context.messages.slice(cp!.history.length), directory, seed);
     const effort = options?.reasoning && EFFORT.test(options.reasoning) ? options.reasoning : this.effort;
     const payload = { transport: "agy-cli", prompt, model: model.id, effort, conversationId: cp?.conversationId };
     const replacement = await options?.onPayload?.(payload, model) as any;
     if (replacement !== undefined && JSON.stringify(replacement) !== JSON.stringify(payload)) throw new Error("agy payload transformations must preserve effective history and native ownership; request not sent");
     await socket.ready();
     this.checkpoint = { version: 2, sessionId: this.sessionId, boundary: ctx.sessionManager.getLeafId(), history: current, outcome: "running", conversationId: cp?.conversationId, offset: cp?.offset, inode: cp?.inode, nativeDigest: cp?.nativeDigest };
     this.persist();
     const runner = new Runner(id, { binary: this.binary, cwd: ctx.cwd, prompt, model, effort, checkpoint: this.checkpoint, env: { PI_AGY_BRIDGE_SOCK: socket.filename, PI_AGY_BRIDGE_TOKEN: socket.token, PI_AGY_BRIDGE_TURN: id }, options }, () => this.status());
     this.active = { runner, socket, directory, finished: false };
     await runner.start();
    } catch (error) {
     if (!this.active || this.active.directory !== directory) { await socket.close(); fs.rmSync(directory, { recursive: true, force: true }); }
     throw error;
    }
   }
   const active = this.active!, runner = active.runner;
   additionalAbort = () => { runner.cancel(); this.harness?.cancelSync(runner.id); };
   options?.signal?.addEventListener("abort", additionalAbort, { once: true }); if (options?.signal?.aborted) additionalAbort();
   if (runner.child?.pid) start();
   while (!runner.steps.length && !runner.ended && !runner.aborted && !runner.error) await runner.changed(options?.signal);
   if (runner.aborted || runner.error) { this.harness?.cancelSync(runner.id); await runner.stopAndConfirm(); }
   if (runner.steps.length && !runner.aborted && !runner.error) {
    const step = runner.steps.shift()!;
    if (step.thinking) output.content.push({ type: "thinking", thinking: step.thinking });
    if (step.text) output.content.push({ type: "text", text: step.text });
    output.content.push({ type: "toolCall", id: step.batch.id, name: "agy_batch", arguments: { summary: step.batch.calls.map(call => call.name).join(" → "), batchId: step.batch.id } });
    output.stopReason = "toolUse";
   } else {
    while (!runner.ended) await runner.changed(options?.signal);
    if (runner.finalThinking) output.content.push({ type: "thinking", thinking: runner.finalThinking });
    if (runner.finalText) output.content.push({ type: "text", text: runner.finalText });
    output.stopReason = runner.aborted ? "aborted" : runner.error ? "error" : "stop";
    if (output.stopReason === "error" || output.stopReason === "aborted") output.errorMessage = runner.aborted ? "Cancelled" : runner.error;
    output.usage = runner.usage;
    if (runner.rawUsage) output.diagnostics = [{ type: "agy-cli-accounting", timestamp: Date.now(), details: { nativeUsage: runner.rawUsage, counters: "terminal native counters counted once; cache/reasoning semantics unverified", cost: "unknown; zero cost fields are SDK placeholders" } }];
    active.finished = true;
    if (output.stopReason === "stop") Object.assign(this.checkpoint!, runner.checkpoint(), { outcome: "running", terminalFingerprint: fingerprint(output) });
    else Object.assign(this.checkpoint!, { outcome: output.stopReason, needsNew: "Prior native turn failed/was cancelled; use /agy-new" });
   }
   appendAssistant(this.checkpoint!, output); this.persist();
   if (active.finished) await this.cleanupActive(active);
   return output;
  } catch (error) {
   if (this.active) {
    this.active.runner.cancel(); this.harness?.cancelSync(this.active.runner.id);
    try { await this.cleanupActive(this.active); } catch (cleanup) { this.warn(errorText(cleanup)); }
   }
   this.invalidate(`agy turn is unverified: ${errorText(error)}; use /agy-new`);
   this.checkpoint!.outcome = options?.signal?.aborted ? "aborted" : "error"; this.persist();
   output.stopReason = options?.signal?.aborted ? "aborted" : "error"; output.errorMessage = errorText(error); return output;
  } finally { if (additionalAbort) options?.signal?.removeEventListener("abort", additionalAbort); this.requesting = false; }
 }
 private async observe(batchId: string, toolCallId: string, signal?: AbortSignal, onUpdate?: any) {
  const runner = this.active?.runner, batch = runner?.batches.get(batchId);
  if (!runner || !batch || this.disposed) throw new Error("No owned native planner batch");
  while (!batch.complete && !runner.ended && !signal?.aborted) {
   onUpdate?.({ content: [{ type: "text", text: "Native batch running; individual operation outcomes are unassociated/unknown" }], details: { correlation: "batch-only" } });
   await runner.changed(signal);
  }
  if (signal?.aborted) { runner.cancel(); throw new Error("Cancelled"); }
  const value: NativeBatch = structuredClone(batch);
  if (!batch.complete) { value.complete = true; value.nativeOutcome = "incomplete"; }
  const content = [{ type: "text" as const, text: JSON.stringify(value) }];
  const isError = value.nativeOutcome === "error" || value.nativeOutcome === "incomplete";
  this.checkpoint!.history.push(fingerprint({ role: "toolResult", toolCallId, toolName: "agy_batch", content, isError })); this.persist();
  runner.batches.delete(batchId);
  return { content, details: value, structuredContent: value, isError };
 }
 private flush() {
  if (this.disposed || !this.ctx || !this.ledger) return;
  try {
   this.ledger.reconcile(this.ctx.sessionManager.getEntries());
   if (!this.enabled || this.ctx.model?.provider !== "agy" || !this.ctx.isIdle() || this.active || this.requesting) return;
   const batch = this.ledger.pending(this.ctx.sessionManager.getBranch()).find(batch => !this.notices.has(batch.noticeId));
   if (!batch) return;
   this.notices.add(batch.noticeId);
   this.pi.sendMessage({ customType: "agy-subagent-result", display: true, content: "<pi_background_subagent_completion>\nPi subagent results (best-effort completion notice). Synthesize and continue the task.\n\n" + this.ledger.notice(batch.id) + "\n</pi_background_subagent_completion>", details: { noticeId: batch.noticeId, batchId: batch.id } }, { deliverAs: "followUp", triggerTurn: true });
  } catch (error) { this.warn(`Completion delivery failed; durable results retained: ${errorText(error)}`); }
 }
 private async stop() {
  const active = this.active;
  if (!active || active.finished) return false;
  active.runner.cancel(); this.harness?.cancelSync(active.runner.id); await active.runner.stopAndConfirm();
  return true;
 }
 async dispose(): Promise<void> {
  if (this.disposal) return this.disposal;
  this.disposed = true;
  this.disposal = (async () => {
   if (this.active) { this.active.runner.cancel(); this.harness?.cancelSync(this.active.runner.id); await this.cleanupActive(this.active); }
   this.harness?.dispose(); this.ledger?.dispose(); this.cleanupResource?.(); release(this);
   this.ctx?.ui.setWidget("agy-live", undefined); this.ctx = undefined;
  })();
  return this.disposal;
 }
 private register() {
  this.observer = { name: "agy_batch", label: "agy batch", exposure: "hidden", description: "Read-only observer of one native agy planner batch. Never executes operations. Ordered calls plus unassociated native results; individual operational outcomes remain unknown.", parameters: ObserverParams,
   execute: (id: string, args: { batchId: string }, signal?: AbortSignal, update?: any) => this.observe(args.batchId, id, signal, update),
   renderCall: (args: any, theme: any) => new Text(theme.bold("agy batch") + " " + args.summary + "\n" + theme.fg("dim", "correlation: batch-only; individual outcomes unknown"), 0, 0),
   renderResult: (result: any, options: any, theme: any) => {
    const value = text(result.content); const limit = options.expanded ? 24000 : 1600;
    const preview = value.length > limit ? value.slice(0, limit) + "\n[Display preview; full result remains in the tool transcript]" : value;
    return new Text(options.isPartial ? theme.fg("dim", preview) : preview, 0, 0);
   },
  };
  this.pi.registerTool(this.observer);
  this.pi.on("session_start", async (_event, ctx) => {
   this.initialize(ctx);
   let selected = ctx.model?.provider === "agy" || ctx.mode === "tui";
   for (const entry of ctx.sessionManager.getBranch()) if (entry.type === "custom" && entry.customType === "agy-bridge:mode-v2") {
    const state = entry.data as any; selected = state.enabled === true;
    if (typeof state.model === "string") this.model = baseModel(state.model); if (EFFORT.test(state.effort)) this.effort = state.effort;
    if (state.fallbackProvider !== "agy" && state.fallbackModel) this.fallback = ctx.modelRegistry.find(state.fallbackProvider, state.fallbackModel);
   }
   if (selected) await this.select(true, ctx); else { this.enabled = false; this.tools(false); }
   this.flush();
  });
  this.pi.on("before_agent_start", (_event, ctx) => { this.initialize(ctx); this.commitTerminal(); this.enabled = ctx.model?.provider === "agy"; this.tools(this.enabled); });
  this.pi.on("before_provider_request", (event, ctx) => {
   if ((event.payload as any)?.kind !== ROUTE_PROBE) return;
   this.initialize(ctx);
   return { ownerToken: this.token, sessionId: this.sessionId, generation: this.generation };
  });
  this.pi.on("session_tree", (_event, ctx) => { this.initialize(ctx); this.invalidate("Pi tree navigation requires /agy-new"); this.persist(); });
  this.pi.on("session_compact", (_event, ctx) => { this.initialize(ctx); this.invalidate("Pi compaction requires /agy-new"); this.persist(); });
  this.pi.on("session_before_compact", (_event, ctx) => { if (ctx.model?.provider === "agy") { this.warn("Select a non-agy model for Pi compaction, then use /agy-new to seed its effective history"); return { cancel: true }; } });
  this.pi.on("model_select", (event, ctx) => {
   this.initialize(ctx); if (this.syncing) return;
   this.enabled = event.model.provider === "agy";
   if (this.enabled) { this.model = event.model.id; if (event.previousModel?.provider !== "agy") this.fallback = event.previousModel; }
   else { this.fallback = event.model; this.fallbackThinking = this.pi.getThinkingLevel(); }
   this.tools(this.enabled);
   this.pi.appendEntry("agy-bridge:mode-v2", { enabled: this.enabled, model: this.model, effort: this.effort, fallbackProvider: this.fallback?.provider, fallbackModel: this.fallback?.id });
  });
  this.pi.on("thinking_level_select", (event, ctx) => { if (this.syncing) return; this.initialize(ctx); if (ctx.model?.provider === "agy" && EFFORT.test(event.level)) this.effort = event.level; });
  this.pi.on("input", (event, ctx) => {
   if (ctx.mode !== "tui" || ctx.model?.provider !== "agy" || event.source !== "interactive" || event.text.trim().startsWith("/") || this.mentionsRunning(event.text)) return { action: "continue" };
   if (!ctx.isIdle() || this.active) { this.pi.sendUserMessage([{ type: "text", text: event.text }, ...(event.images ?? [])], { deliverAs: "followUp" }); return { action: "handled" }; }
   return { action: "continue" };
  });
  this.pi.on("agent_settled", (_event, ctx) => { if (this.disposed) return; this.initialize(ctx); this.commitTerminal(); this.ledger?.reconcile(ctx.sessionManager.getEntries()); this.notices.clear(); this.ledger?.prune(); this.flush(); });
  this.pi.on("session_shutdown", () => { this.commitTerminal(); return this.dispose(); });
  this.pi.on("session_before_tree", () => {
   this.ledger?.reconcile(this.requireContext().sessionManager.getEntries());
   const queued = this.ledger?.pending(this.requireContext().sessionManager.getBranch()).some(batch => this.notices.has(batch.noticeId));
   if ((this.active && !this.active.runner.exited) || queued) { this.warn("Stop the owned agy runner / finish queued completion delivery before Pi tree navigation"); return { cancel: true }; }
  });
  this.pi.registerMessageRenderer("agy-subagent-result", (message, options, theme) => new Text(theme.fg("dim", "Pi subagent completion (best effort)") + (options.expanded ? "\n" + text(message.content) : ""), 0, 0));
  this.pi.registerMessageRenderer("agy-user", (message, options) => new UserMessageComponent(text(message.content), getMarkdownTheme(), options.outputPad));
  this.pi.registerMessageRenderer("agy-assistant", (message, options) => {
   const details = message.details as any; const content: any[] = [];
   if (details?.thinking) content.push({ type: "thinking", thinking: details.thinking }); if (text(message.content)) content.push({ type: "text", text: text(message.content) });
   return new AssistantMessageComponent({ role: "assistant", content, stopReason: details?.stopReason ?? "stop", errorMessage: details?.errorMessage } as any, Boolean(this.pi.getSettings().hideThinkingBlock) && !options.expanded, getMarkdownTheme(), "Thinking...", options.outputPad);
  });
  this.pi.registerCommand("agy-mode", { description: "agy bridge on/off/status", handler: async (args, ctx) => {
   this.initialize(ctx); const sub = args.trim().toLowerCase();
   if (sub === "on" || (!sub && !this.enabled)) await this.select(true, ctx); else if (sub === "off" || (!sub && this.enabled)) await this.select(false, ctx); else if (sub !== "status") { ctx.ui.notify("Usage: /agy-mode [on|off|status]", "warning"); return; }
   ctx.ui.notify(`agy ${this.enabled ? "ON" : "OFF"} · ${this.model} (${this.effort}) · conversation ${this.checkpoint?.conversationId ?? "new"} · ${this.checkpoint?.needsNew ?? "checkpoint verified on next request"} · token/cost usage unknown`, "info");
  } });
  this.pi.registerCommand("agy-model", { description: "Select agy model [effort]", handler: async (args, ctx) => {
   const [id, explicit] = args.trim().split(/\s+/); if (!id) { ctx.ui.notify(`agy model ${this.model} (${this.effort}); /agy-model <model> [effort]`, "info"); return; }
   const effort = explicit ?? (!SEMANTIC_SUFFIX.test(id) ? /-(low|medium|high|xhigh|max)$/i.exec(id)?.[1]?.toLowerCase() : undefined);
   if (effort && !EFFORT.test(effort)) throw new Error("Invalid agy effort"); this.model = baseModel(id); if (effort) this.effort = effort; await this.select(true, ctx);
  } });
  this.pi.registerCommand("agy-effort", { description: "Set agy low/medium/high/xhigh/max", handler: async (args, ctx) => { this.initialize(ctx); const next = args.trim().toLowerCase(); if (!EFFORT.test(next)) { ctx.ui.notify(`/agy-effort <low|medium|high|xhigh|max>; current ${this.effort}`, "info"); return; } this.effort = next; if (ctx.model?.provider === "agy") await this.select(true, ctx); } });
  this.pi.registerCommand("agy-new", { description: "Seed a fresh native conversation from full effective Pi history on the next turn", handler: async (_args, ctx) => {
   this.initialize(ctx); if (this.requesting || (this.active && !this.active.runner.exited)) throw new Error("Stop and confirm the owned agy runner before /agy-new");
   if (this.active) await this.cleanupActive(this.active); this.checkpoint = undefined;
   // Persist explicit reset without reconstructing historical raw entries.
   this.pi.appendEntry(STATE_ENTRY, { version: 2, sessionId: this.sessionId, boundary: ctx.sessionManager.getLeafId(), history: [], outcome: "success" });
   ctx.ui.notify("Next agy turn will seed full current effective Pi history; no native conversation was started yet", "info");
  } });
  this.pi.registerCommand("agy-stop", { description: "Cancel only this owned agy runner, preserving Pi queued follow-ups", handler: async (_args, ctx) => { this.initialize(ctx); ctx.ui.notify(await this.stop() ? "Owned agy process exited; queued Pi follow-ups preserved" : "No agy runner is active", "info"); } });
 }
}
export function install(pi: ExtensionAPI) {
 if (process.env.PI_AGY_BRIDGE_DISABLE === "1" || process.env.PI_SUBAGENT_CHILD === "1") return;
 const binary = resolveBinary(); if (!binary) return;
 new Controller(pi, binary);
}
