import { randomUUID } from "node:crypto";
import { createAssistantMessageEventStream, type AssistantMessage, type Model, type SimpleStreamOptions, type TranscriptContext } from "@earendil-works/pi-ai";

const KEY = Symbol.for("pi-agy-bridge:owners:v2");
export const ROUTE_PROBE = "agy-cli:owner-route-v2";
export interface Owner {
 token: string; sessionId: string; generation: string; disposed: boolean;
 request(model: Model<any>, context: TranscriptContext, options: SimpleStreamOptions | undefined, start: () => void): Promise<AssistantMessage>;
}
type Registry = { version: 2; owners: Map<string, Owner>; sessions: Map<string, string>; models: Map<string, any> };
function registry(): Registry {
 const globals = globalThis as any;
 if (globals[KEY] && globals[KEY].version !== 2) throw new Error("Incompatible agy ownership registry; restart is required");
 return globals[KEY] ??= { version: 2, owners: new Map(), sessions: new Map(), models: new Map() };
}
export function sharedModels(models: Array<{ id: string }>): any[] {
 const r = registry(); for (const model of models) r.models.set(model.id, model); return [...r.models.values()];
}
export function token(): string { return randomUUID(); }
export function claim(owner: Owner): void {
 const r = registry(), existing = r.sessions.get(owner.sessionId);
 if (existing && existing !== owner.token) throw new Error("Ambiguous duplicate Pi session owner; agy request refused");
 r.sessions.set(owner.sessionId, owner.token); r.owners.set(owner.token, owner);
}
export function release(owner: Owner): void {
 const r = registry();
 if (r.owners.get(owner.token) === owner) r.owners.delete(owner.token);
 if (r.sessions.get(owner.sessionId) === owner.token) r.sessions.delete(owner.sessionId);
}
export function zeroUsage() {
 return { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } };
}
export function emptyMessage(model: Model<any>): AssistantMessage {
 return { role: "assistant", api: "agy-cli", provider: "agy", model: model.id, content: [], usage: zeroUsage(), stopReason: "pending", timestamp: Date.now(),
  diagnostics: [{ type: "agy-cli-accounting", timestamp: Date.now(), details: { accounting: "unknown", transport: "CLI (no HTTP response)", zeroFields: "SDK placeholders, not measured free usage" } }] };
}
function blocks(stream: ReturnType<typeof createAssistantMessageEventStream>, partial: AssistantMessage, final: AssistantMessage) {
 for (const block of final.content) {
  const contentIndex = partial.content.length;
  if (block.type === "text") {
   const current = { ...block, text: "" }; partial.content.push(current);
   stream.push({ type: "text_start", contentIndex, partial }); current.text = block.text;
   if (block.text) stream.push({ type: "text_delta", contentIndex, delta: block.text, partial });
   stream.push({ type: "text_end", contentIndex, content: current.text, partial });
  } else if (block.type === "thinking") {
   const current = { ...block, thinking: "" }; partial.content.push(current);
   stream.push({ type: "thinking_start", contentIndex, partial }); current.thinking = block.thinking;
   if (block.thinking) stream.push({ type: "thinking_delta", contentIndex, delta: block.thinking, partial });
   stream.push({ type: "thinking_end", contentIndex, content: current.thinking, partial });
  } else {
   const current = { ...block, arguments: {} }; partial.content.push(current);
   stream.push({ type: "toolcall_start", contentIndex, partial }); current.arguments = block.arguments;
   stream.push({ type: "toolcall_delta", contentIndex, delta: JSON.stringify(block.arguments), partial });
   stream.push({ type: "toolcall_end", contentIndex, toolCall: current, partial });
  }
 }
}
// Every registered provider uses this same stateless dispatcher. The hook belongs to
// the requesting SDK session, not to the last extension factory that registered agy.
export function dispatch(model: Model<any>, context: TranscriptContext, options?: SimpleStreamOptions) {
 const stream = createAssistantMessageEventStream(), partial = emptyMessage(model);
 let started = false;
 const start = () => { if (!started) { started = true; stream.push({ type: "start", partial }); } };
 void (async () => {
  try {
   const route = await options?.onPayload?.({ transport: "agy-cli", kind: ROUTE_PROBE }, model) as any;
   const owner = registry().owners.get(route?.ownerToken);
   if (!owner || owner.disposed || route?.generation !== owner.generation || route?.sessionId !== owner.sessionId || options?.sessionId !== owner.sessionId) {
    throw new Error("No verified session-owned agy route (direct/compaction calls are unsupported); use a bound Pi session");
   }
   const final = await owner.request(model, context, options, start);
   if (started || !["error", "aborted"].includes(final.stopReason) || final.content.length) { start(); blocks(stream, partial, final); }
   Object.assign(partial, { usage: final.usage, diagnostics: final.diagnostics, stopReason: final.stopReason, errorMessage: final.errorMessage });
   if (final.stopReason === "error" || final.stopReason === "aborted") stream.push({ type: "error", reason: final.stopReason, error: structuredClone(partial) });
   else stream.push({ type: "done", reason: final.stopReason as "stop" | "toolUse" | "length", message: structuredClone(partial) });
  } catch (error) {
   partial.stopReason = options?.signal?.aborted ? "aborted" : "error";
   partial.errorMessage = error instanceof Error ? error.message : String(error);
   stream.push({ type: "error", reason: partial.stopReason, error: structuredClone(partial) });
  } finally { stream.end(); }
 })();
 return stream;
}
