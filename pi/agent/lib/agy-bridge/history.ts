import { createHash } from "node:crypto";
import * as fs from "node:fs";
import * as path from "node:path";
import type { TranscriptContext, AssistantMessage } from "@earendil-works/pi-ai";

export const STATE_ENTRY = "agy-bridge:checkpoint-v2";
export const MAX_PROMPT_BYTES = 96 * 1024;
export type Checkpoint = {
 version: 2; sessionId: string; boundary: string | null; conversationId?: string;
 offset?: number; inode?: number; nativeDigest?: string; history: string[];
 outcome: "running" | "success" | "error" | "aborted" | "unknown";
 needsNew?: string; terminalFingerprint?: string; committedEntryId?: string;
};
function stable(value: any): any {
 if (Array.isArray(value)) return value.map(stable);
 if (value && typeof value === "object") return Object.fromEntries(Object.keys(value).sort().map(k => [k, stable(value[k])]));
 return value;
}
// Provider-facing semantics only: SDK accounting/timestamps are not context.
export function messageValue(message: any): any {
 const value: any = { role: message.role, content: message.content };
 for (const key of ["sections", "toolsAdded", "toolsRemoved", "toolCallId", "toolName", "isError"]) {
  if (message[key] !== undefined) value[key] = message[key];
 }
 return stable(value);
}
export function fingerprint(message: any): string {
 return createHash("sha256").update(JSON.stringify(messageValue(message))).digest("hex");
}
export function history(context: TranscriptContext): string[] { return context.messages.map(fingerprint); }
export function isPrefix(prefix: string[], all: string[]): boolean {
 return prefix.length <= all.length && prefix.every((value, i) => value === all[i]);
}
export function appendAssistant(checkpoint: Checkpoint, message: AssistantMessage): void { checkpoint.history.push(fingerprint(message)); }
export function nativePath(id: string, home = process.env.HOME || ""): string {
 if (!/^[a-zA-Z0-9][a-zA-Z0-9._-]*$/.test(id)) throw new Error("Invalid native conversation id");
 return path.join(home, ".gemini/antigravity-cli/brain", id, ".system_generated/logs/transcript_full.jsonl");
}
export function digestDescriptor(fd: number, bytes: number, guards: Array<{ bytes: number; digest: string }> = []): { digest: string; inode: number } {
  const stat = fs.fstatSync(fd);
  if (!stat.isFile() || stat.size < bytes) throw new Error("Native transcript boundary is missing/truncated; use /agy-new");
  const hash = createHash("sha256"), buffer = Buffer.alloc(64 * 1024);
  const prefixes = guards.map(guard => ({ ...guard, hash: createHash("sha256") }));
  let offset = 0;
  while (offset < bytes) {
   const count = fs.readSync(fd, buffer, 0, Math.min(buffer.length, bytes - offset), offset);
   if (!count) throw new Error("Native transcript changed while checking checkpoint");
   hash.update(buffer.subarray(0, count));
   for (const prefix of prefixes) if (offset < prefix.bytes) prefix.hash.update(buffer.subarray(0, Math.min(count, prefix.bytes - offset)));
   offset += count;
  }
  for (const prefix of prefixes) if (bytes < prefix.bytes || prefix.hash.digest("hex") !== prefix.digest) throw new Error("Native transcript saved prefix changed during owned turn");
  return { digest: hash.digest("hex"), inode: stat.ino };
}
export function digestFile(filename: string, bytes: number): { digest: string; inode: number } {
 const fd = fs.openSync(filename, "r");
 try { return digestDescriptor(fd, bytes); } finally { fs.closeSync(fd); }
}
export function verifyNative(checkpoint: Checkpoint): void {
 if (!checkpoint.conversationId || checkpoint.offset === undefined || checkpoint.nativeDigest === undefined) throw new Error("Unverified native checkpoint; use /agy-new");
 const filename = nativePath(checkpoint.conversationId);
 const stat = fs.statSync(filename);
 // An external writer invalidates ownership even if our saved prefix still exists.
 if (stat.size !== checkpoint.offset) throw new Error("Native conversation advanced outside this owner; use /agy-new");
 const value = digestFile(filename, checkpoint.offset);
 if (value.inode !== checkpoint.inode || value.digest !== checkpoint.nativeDigest) throw new Error("Native conversation checkpoint changed; use /agy-new");
}
export function promptFor(messages: any[], directory: string, seed: boolean): string {
 const images: string[] = [];
 const encoded = messages.map(message => {
  const value = messageValue(message);
  if (Array.isArray(value.content)) value.content = value.content.map((block: any) => {
   if (block.type !== "image") return block;
   if (typeof block.data !== "string" || typeof block.mimeType !== "string") throw new Error("Invalid image input");
   const extension = block.mimeType.split("/")[1]?.replace(/[^a-z0-9]/gi, "") || "bin";
   const filename = path.join(directory, `image-${images.length}.${extension}`);
   fs.writeFileSync(filename, Buffer.from(block.data, "base64"), { mode: 0o600 }); images.push(filename);
   return { type: "text", text: `Attached image (${block.mimeType}); view with read_file: ${filename}` };
  });
  return value;
 });
 const prompt = (seed ? "<pi_effective_history>\nThis is the complete current effective Pi transcript, including system instructions and tool declarations. Continue it; do not re-execute historical tool calls. Native agy executes tools; agy_batch is only a Pi observer. Delegate with pi-bridge pi_subagent; background completion notices are best effort.\n" : "<pi_continuation>\nNew effective Pi transcript messages, in order:\n")
  + JSON.stringify(encoded) + (seed ? "\n</pi_effective_history>" : "\n</pi_continuation>");
 if (Buffer.byteLength(prompt) > MAX_PROMPT_BYTES) throw new Error(`Effective history exceeds the verified -p transport limit (${MAX_PROMPT_BYTES} bytes). Compact/edit Pi context explicitly, then /agy-new; nothing was truncated or sent.`);
 return prompt;
}
