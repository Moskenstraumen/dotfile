#!/usr/bin/env node
// Standalone agy discovers no tools; turn-owned credentials are supplied only by Pi.
import { callBridge, runMcp } from "../lib/agy-bridge/protocol.mjs";

function result(value, isError = false) {
 return { content: [{ type: "text", text: JSON.stringify(value, null, 2) }], structuredContent: value, isError };
}
const failed = agents => agents.some(agent => agent.status !== "completed" || agent.error || agent.isError || (agent.exitCode !== undefined && agent.exitCode !== null && agent.exitCode !== 0) || agent.signal);
runMcp(async (name, args, signal) => {
 if (name === "pi_subagent") {
  const tasks = args.tasks ?? (args.type && args.prompt ? [{ type: args.type, prompt: args.prompt, description: args.description, cwd: args.cwd }] : []);
  const value = await callBridge("subagent_spawn", { tasks, wait: args.wait ?? false, timeoutMs: args.timeoutMs }, signal);
  return result(value, value.results ? failed(value.results) : false);
 }
 if (name === "pi_subagent_status") return result(await callBridge("subagent_status", { ids: args.ids }, signal));
 if (name === "pi_subagent_wait") {
  const value = await callBridge("subagent_wait", { ids: args.ids, timeoutMs: args.timeoutMs }, signal);
  return result(value, failed(value.results));
 }
 if (name === "pi_subagent_steer") return result(await callBridge("subagent_steer", { agentId: args.agentId, message: args.message }, signal));
 if (name === "pi_subagent_stop") return result(await callBridge("subagent_stop", { agentId: args.agentId }, signal));
 if (name === "pi_ask_user") return result(await callBridge("ask_user", { question: args.question, options: args.options, placeholder: args.placeholder }, signal));
 throw new Error(`Unknown tool: ${name}`);
});
