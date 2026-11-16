import * as net from "node:net";
import { randomUUID } from "node:crypto";
export const MAX_FRAME = 1024 * 1024;
export const MAX_DEADLINE_MS = 60000;
const str = { type: "string", minLength: 1 };
const ids = { type: "array", minItems: 1, maxItems: 32, items: str };
const task = { type: "object", additionalProperties: false, properties: { type: { type: "string", enum: ["reader", "thinker", "implementer"] }, prompt: str, description: { type: "string" }, cwd: { type: "string" } }, required: ["type", "prompt"] };
const timeout = { type: "integer", minimum: 1, maximum: 30000, default: 30000 };
export const TOOLS = [
 { name: "pi_subagent", description: "Launch Pi reader/thinker/implementer subagents, singly or in a batch. Defaults to background. Completion notices are durable best effort; status/wait are nonconsuming. A launch timeout has unknown outcome: do not retry by spawning again.", inputSchema: { type: "object", properties: { ...task.properties, tasks: { type: "array", minItems: 1, maxItems: 16, items: task }, wait: { type: "boolean", default: false }, timeoutMs: timeout } } },
 { name: "pi_subagent_status", description: "Read-only status of this branch's bridge-owned agents. Missing operational status is unknown, not queued or successful.", inputSchema: { type: "object", properties: { ids } } },
 { name: "pi_subagent_wait", description: "Wait up to timeoutMs for owned agent results. Read-only; timeout/cancellation does not consume results or stop agents.", inputSchema: { type: "object", properties: { ids, timeoutMs: timeout }, required: ["ids"] } },
 { name: "pi_subagent_steer", description: "Request next safe-boundary steering for one owned Pi subagent.", inputSchema: { type: "object", properties: { agentId: str, message: str }, required: ["agentId", "message"] } },
 { name: "pi_subagent_stop", description: "Request cancellation of one owned Pi subagent; acceptance does not prove it stopped.", inputSchema: { type: "object", properties: { agentId: str }, required: ["agentId"] } },
 { name: "pi_ask_user", description: "Ask the Pi TUI/RPC user via a bounded selector or text input.", inputSchema: { type: "object", properties: { question: str, options: { type: "array", maxItems: 16, items: str }, placeholder: { type: "string" } }, required: ["question"] } },
];
export function validate(method, params) {
 if (!params || typeof params !== "object" || Array.isArray(params)) throw new Error("Parameters must be an object");
 const nonempty = value => typeof value === "string" && value.trim().length > 0;
 if (params.timeoutMs !== undefined && (!Number.isInteger(params.timeoutMs) || params.timeoutMs < 1 || params.timeoutMs > 30000)) throw new Error("timeoutMs must be 1..30000");
 if (method === "subagent_spawn") {
  if (!Array.isArray(params.tasks) || !params.tasks.length || params.tasks.length > 16) throw new Error("Provide 1..16 tasks");
  for (const task of params.tasks) if (!task || !["reader", "thinker", "implementer"].includes(task.type) || !nonempty(task.prompt) || (task.cwd !== undefined && (typeof task.cwd !== "string" || !task.cwd.startsWith("/")))) throw new Error("Invalid role/prompt/absolute cwd");
  if (params.wait !== undefined && typeof params.wait !== "boolean") throw new Error("wait must be boolean");
 } else if (["subagent_status", "subagent_wait"].includes(method)) {
  if (params.ids !== undefined && (!Array.isArray(params.ids) || params.ids.length > 32 || !params.ids.every(nonempty))) throw new Error("Invalid agent IDs");
  if (method === "subagent_wait" && !params.ids?.length) throw new Error("Provide agent IDs");
 } else if (["subagent_steer", "subagent_stop"].includes(method)) {
  if (!nonempty(params.agentId) || (method === "subagent_steer" && !nonempty(params.message))) throw new Error("Invalid agentId/message");
 } else if (method === "ask_user") {
  if (!nonempty(params.question) || (params.options !== undefined && (!Array.isArray(params.options) || params.options.length > 16 || !params.options.every(nonempty)))) throw new Error("Invalid UI question/options");
 } else throw new Error(`Unknown method: ${method}`);
}
export class Frames {
 buffer = Buffer.alloc(0);
 contentLength = false;
 push(chunk) {
  this.buffer = Buffer.concat([this.buffer, Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk)]);
  if (this.buffer.length > MAX_FRAME * 4) throw new Error("Buffered input exceeds frame budget");
  const result = [];
  while (this.buffer.length) {
   const prefix = "Content-Length:";
   const head = this.buffer.subarray(0, Math.min(prefix.length, this.buffer.length)).toString();
   if (prefix.startsWith(head) && head.length < prefix.length) break;
   if (head === prefix) {
    this.contentLength = true;
    const end = this.buffer.indexOf("\r\n\r\n");
    if (end < 0) { if (this.buffer.length > 4096) throw new Error("Oversized frame header"); break; }
    const header = this.buffer.subarray(0, end).toString();
    const match = /^Content-Length: (\d+)$/i.exec(header);
    if (!match) throw new Error("Invalid Content-Length header");
    const size = Number(match[1]);
    if (!Number.isSafeInteger(size) || size < 1 || size > MAX_FRAME) throw new Error("Invalid frame size");
    if (this.buffer.length < end + 4 + size) break;
    result.push(JSON.parse(this.buffer.subarray(end + 4, end + 4 + size).toString("utf8"))); this.buffer = this.buffer.subarray(end + 4 + size);
   } else {
    const end = this.buffer.indexOf(10);
    if (end < 0) { if (this.buffer.length > MAX_FRAME) throw new Error("Oversized NDJSON frame"); break; }
    if (end > MAX_FRAME) throw new Error("Oversized NDJSON frame");
    const line = this.buffer.subarray(0, end).toString("utf8").trim(); this.buffer = this.buffer.subarray(end + 1);
    if (line) result.push(JSON.parse(line));
   }
  }
  return result;
 }
}
export function callBridge(method, params, signal) {
 validate(method, params);
 const sockPath = process.env.PI_AGY_BRIDGE_SOCK, token = process.env.PI_AGY_BRIDGE_TOKEN, turnId = process.env.PI_AGY_BRIDGE_TURN;
 if (!sockPath || !token || !turnId) throw new Error("No active session-owned Pi bridge endpoint");
 const id = randomUUID(), deadline = Date.now() + MAX_DEADLINE_MS;
 return new Promise((resolve, reject) => {
  const socket = net.createConnection(sockPath), frames = new Frames();
  let settled = false;
  const finish = (error, value) => { if (settled) return; settled = true; clearTimeout(timer); signal?.removeEventListener("abort", abort); socket.destroy(); error ? reject(error) : resolve(value); };
  const abort = () => finish(new Error("Bridge request cancelled; launch/stop outcome may be unknown"));
  const timer = setTimeout(() => finish(new Error("Bridge deadline exceeded; launch/stop outcome unknown; do not respawn")), MAX_DEADLINE_MS);
  signal?.addEventListener("abort", abort, { once: true });
  socket.on("connect", () => {
   if (signal?.aborted) { abort(); return; }
   const frame = JSON.stringify({ id, token, turnId, deadline, method, params }) + "\n";
   if (Buffer.byteLength(frame) > MAX_FRAME) { finish(new Error("Oversized bridge request")); return; }
   socket.write(frame);
  });
  socket.on("data", chunk => {
   try { for (const response of frames.push(chunk)) {
    if (!response || response.id !== id || typeof response.ok !== "boolean") throw new Error("Invalid/mismatched bridge response");
    if (response.ok) finish(undefined, response.result);
    else { const error = new Error(response.error || "Pi bridge failed"); error.details = response.details; finish(error); }
   } } catch (error) { finish(error); }
  });
  socket.on("error", error => finish(error)); socket.on("close", () => finish(new Error("Bridge closed without reply; operational outcome unknown")));
  if (signal?.aborted) abort();
 });
}
export function runMcp(handleTool) {
 const frames = new Frames(), active = new Map();
 const send = message => { const json = JSON.stringify(message); process.stdout.write(frames.contentLength ? `Content-Length: ${Buffer.byteLength(json)}\r\n\r\n${json}` : json + "\n"); };
 async function dispatch(message) {
  if (!message || message.jsonrpc !== "2.0" || typeof message.method !== "string") { send({ jsonrpc: "2.0", id: null, error: { code: -32600, message: "Invalid request" } }); return; }
  if (message.method === "notifications/cancelled") { active.get(message.params?.requestId)?.abort(); return; }
  const id = message.id;
  if (id === undefined || id === null) return;
  if (!(typeof id === "string" || (typeof id === "number" && Number.isFinite(id)))) { send({ jsonrpc: "2.0", id: null, error: { code: -32600, message: "Invalid request id" } }); return; }
  if (active.has(id) || active.size >= 32) { send({ jsonrpc: "2.0", id, error: { code: -32600, message: "Duplicate id or too many active requests" } }); return; }
  const abort = new AbortController(); active.set(id, abort);
  try {
   let result;
   if (message.method === "initialize") result = { protocolVersion: "2024-11-05", capabilities: { tools: {} }, serverInfo: { name: "pi-bridge", version: "2.0.0" } };
   else if (message.method === "ping") result = {};
   else if (message.method === "tools/list") result = { tools: process.env.PI_AGY_BRIDGE_SOCK && process.env.PI_AGY_BRIDGE_TOKEN && process.env.PI_AGY_BRIDGE_TURN ? TOOLS : [] };
   else if (message.method === "resources/list") result = { resources: [] };
   else if (message.method === "prompts/list") result = { prompts: [] };
   else if (message.method === "tools/call") result = await handleTool(message.params?.name, message.params?.arguments ?? {}, abort.signal);
   else { send({ jsonrpc: "2.0", id, error: { code: -32601, message: `Method not found: ${message.method}` } }); return; }
   send({ jsonrpc: "2.0", id, result });
  } catch (error) { send({ jsonrpc: "2.0", id, result: { content: [{ type: "text", text: error.message || String(error) }], structuredContent: { error: error.message || String(error), details: error.details, operationalOutcome: "unknown" }, isError: true } }); }
  finally { active.delete(id); }
 }
 process.stdin.on("data", chunk => { try { for (const message of frames.push(chunk)) void dispatch(message); } catch (error) { send({ jsonrpc: "2.0", id: null, error: { code: -32700, message: error.message } }); frames.buffer = Buffer.alloc(0); } });
 process.stdin.on("end", () => { for (const abort of active.values()) abort.abort(); });
}
