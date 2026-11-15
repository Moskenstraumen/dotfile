// Live model discovery for the gateways in PROVIDERS, each registered as a native pi Provider.
// Lists come from GET <root>/v1/models, authenticated with that provider's auth.json API key.
// No models.json entry is required. If present, pi composes models.json ABOVE the native
// provider: hand-tuned models replace discovered entries with the same id.
// Add a gateway by setting its id, name, root, emptyApiRule, sessionAffinity, and optional headers below.
// Provider headers apply to discovery and every streamed request (including restored snapshots).
//
// Per discovered id (support_apis from the gateway):
//   claude* with claude_native  -> anthropic-messages   baseUrl <root>              (/v1/messages)
//   responses                   -> openai-responses     baseUrl <root>/v1           (/v1/responses)
//   chat                        -> openai-completions   baseUrl <root>/v1           (/v1/chat/completions)
//   generate_content only       -> google-generative-ai baseUrl <root>/gemini/v1beta
//   image/tts/embedding-ish ids -> skipped
// Empty support_apis: Claude uses anthropic-messages; otherwise the provider's emptyApiRule
// either skips (modelproxy) or uses responses for /^gpt-/ and chat for the rest (gw).
// Registered ids are exactly those advertised by the gateway, including Unicode hyphens.
// The OpenAI/Gemini endpoints 404 without those path prefixes (verified against modelproxy).
// pi's models.json layer rewrites every base model's baseUrl to the provider root, so the
// stream wrapper re-applies the per-api prefix when a model's baseUrl is a bare origin.
//
// Metadata (reasoning, thinkingLevelMap, input, contextWindow, maxTokens, cost) comes from
// pi-ai's bundled catalog, matched by id with `:route` suffix, vendor prefix and known
// deployment suffixes stripped, Unicode hyphens normalized for lookup only, and dotted/hyphenated
// trailing version fallbacks. compat flags are never copied (unverified for the gateway).
// Session affinity is opt-in per provider.
// Unknown ids get conservative defaults (reasoning false, text-only, 128k/16k, zero cost).
//
// Snapshot: discovered models persist per provider id in ~/.pi/agent/models-store.json
// (pi's ModelsStore); filtering on restore is retained defensively, including old snapshots.
// Startup restores the snapshot without network. Network refreshes happen when pi allows them
// (interactive start, /model, `pi update --models`), at most every REFRESH_INTERVAL_MS unless
// forced. When no snapshot exists yet, one bootstrap fetch (BOOTSTRAP_TIMEOUT_MS) runs even in
// cache-only phases so `pi --list-models` works on first use; skipped with --offline/PI_OFFLINE.
// Any discovery failure leaves models.json models working (fail open).

import { readFileSync } from "node:fs";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { getAgentDir } from "@earendil-works/pi-coding-agent";
import {
	anthropicMessagesApi,
	envApiKeyAuth,
	getApiProvider,
	getModels as getCatalogModels,
	getProviders as getCatalogProviders,
	googleGenerativeAIApi,
	lazyStream,
	openAICompletionsApi,
	openAIResponsesApi,
} from "@earendil-works/pi-ai/compat";

type ProviderConfig = {
	id: string;
	name: string;
	root: string;
	emptyApiRule: "skip" | "gpt-responses-otherwise-chat";
	sessionAffinity: boolean;
	headers?: Record<string, string>;
};

const PROVIDERS: ProviderConfig[] = [
	{
		id: "modelproxy",
		name: "ModelProxy",
		root: "https://mp.z01.normandyfunc.com",
		emptyApiRule: "skip",
		sessionAffinity: true,
	},
	{
		id: "gw",
		name: "StepX AI GW",
		root: "https://i-ai-gw.stepx.com",
		emptyApiRule: "gpt-responses-otherwise-chat",
		sessionAffinity: false,
	},
	{
		id: "stepcode",
		name: "StepCode",
		root: "https://mp.z01.normandyfunc.com",
		emptyApiRule: "skip",
		// Same gateway/session routing as modelproxy; Responses keeps its existing affinity.
		sessionAffinity: true,
		headers: { "User-Agent": "stepcode/v1.2.90" },
	},
];
const NETWORK_TIMEOUT_MS = 8_000;
const BOOTSTRAP_TIMEOUT_MS = 2_500;
const REFRESH_INTERVAL_MS = 30 * 60 * 1000;

type ApiId = "anthropic-messages" | "openai-responses" | "openai-completions" | "google-generative-ai";

const API_PATH: Record<ApiId, string> = {
	"anthropic-messages": "",
	"openai-responses": "/v1",
	"openai-completions": "/v1",
	"google-generative-ai": "/gemini/v1beta",
};

const FALLBACK_STREAMS: Record<ApiId, () => any> = {
	"anthropic-messages": anthropicMessagesApi,
	"openai-responses": openAIResponsesApi,
	"openai-completions": openAICompletionsApi,
	"google-generative-ai": googleGenerativeAIApi,
};

// Preferred bundled catalogs per api (same wire semantics => thinkingLevelMap is meaningful).
const PREFERRED_CATALOGS: Record<ApiId, string[]> = {
	"anthropic-messages": ["anthropic"],
	"openai-responses": ["openai", "azure-openai-responses"],
	"openai-completions": ["openai", "deepseek", "zai", "moonshotai", "minimax", "xiaomi"],
	"google-generative-ai": ["google"],
};

const SKIP_ID = /(^|[-_/.])(gpt-image|dall-e|tts|whisper|transcribe|embedding|embed|moderation|realtime|audio|rerank)|image/i;

// Trailing `-segment`s that name a deployment rather than a model variant.
const DEPLOYMENT_SEGMENT =
	/^(eval|platform|aipc|aliyun|aliyun2kimi|aliyun2zhipu|tencent2zhipu|tencent|silicon|mix|native|direct|kmood|aistudio|vertex|official|offical|aigc|product|codeplan|\d{4}|\d{8})$/i;

type GatewayModel = { id?: unknown; support_apis?: Array<{ id?: unknown }> };

type CatalogEntry = { model: any; catalog: string };

let catalogIndex: Map<string, CatalogEntry[]> | undefined;
// Same entries keyed by the id after the last "/" (e.g. "stepfun/step-5-preview" -> "step-5-preview").
// Consulted only when no exact/alias key matches, so vendor-prefixed aggregator rows never shadow direct ones.
let vendorlessIndex: Map<string, CatalogEntry[]> | undefined;

function getCatalogIndex(): Map<string, CatalogEntry[]> {
	if (catalogIndex) return catalogIndex;
	const index = new Map<string, CatalogEntry[]>();
	const vendorless = new Map<string, CatalogEntry[]>();
	for (const catalog of getCatalogProviders() as string[]) {
		let models: any[] = [];
		try {
			models = [...(getCatalogModels(catalog as any) as any[])];
		} catch {
			continue;
		}
		for (const model of models) {
			if (!model || typeof model.id !== "string" || (model.type && model.type !== "chat")) continue;
			const key = model.id.toLowerCase();
			const list = index.get(key) ?? [];
			list.push({ model, catalog });
			index.set(key, list);
			const slash = key.lastIndexOf("/");
			if (slash >= 0) {
				const bare = key.slice(slash + 1);
				const bareList = vendorless.get(bare) ?? [];
				bareList.push({ model, catalog });
				vendorless.set(bare, bareList);
			}
		}
	}
	vendorlessIndex = vendorless;
	catalogIndex = index;
	return index;
}

function candidateKeys(id: string): string[] {
	// Catalog matching only: never change the id registered with pi or sent to the gateway.
	let base = id.replace(/[\u2010-\u2015\u2212]/g, "-").split(":")[0].toLowerCase();
	const keys = [base];
	const slash = base.lastIndexOf("/");
	if (slash >= 0) {
		base = base.slice(slash + 1);
		keys.push(base);
	}
	const parts = base.split("-");
	while (parts.length > 1 && DEPLOYMENT_SEGMENT.test(parts[parts.length - 1])) {
		parts.pop();
		keys.push(parts.join("-"));
	}
	// Keep all existing matches ahead of version aliases. Bound version components to avoid
	// treating date suffixes (e.g. -2025-11-01) as a major/minor version.
	const variants = keys.map((key) =>
		key.replace(
			/(^|[^\d.-]-)(\d{1,2})([-.])(\d{1,2})$/,
			(_match, prefix, major, separator, minor) => `${prefix}${major}${separator === "-" ? "." : "-"}${minor}`,
		),
	);
	return [...new Set([...keys, ...variants])];
}

function findCatalogEntry(id: string, api: ApiId): CatalogEntry | undefined {
	return findIn(getCatalogIndex(), id, api) ?? findIn(vendorlessIndex ?? new Map(), id, api);
}

function findIn(index: Map<string, CatalogEntry[]>, id: string, api: ApiId): CatalogEntry | undefined {
	for (const key of candidateKeys(id)) {
		const entries = index.get(key);
		if (!entries?.length) continue;
		for (const catalog of PREFERRED_CATALOGS[api]) {
			const hit = entries.find((entry) => entry.catalog === catalog);
			if (hit) return hit;
		}
		return entries.find((entry) => entry.model.api === api) ?? entries[0];
	}
	return undefined;
}

function chooseApi(config: ProviderConfig, id: string, apis: Set<string>): ApiId | undefined {
	if (SKIP_ID.test(id)) return undefined;
	if (apis.has("image_gen") || apis.has("image_edit")) return undefined;
	const isClaude = /^claude/i.test(id);
	if (isClaude && (apis.has("claude_native") || apis.size === 0)) return "anthropic-messages";
	if (apis.has("responses")) return "openai-responses";
	if (apis.has("chat")) return "openai-completions";
	if (apis.has("claude_native")) return "anthropic-messages";
	if (apis.has("generate_content")) return "google-generative-ai";
	if (apis.size === 0 && config.emptyApiRule === "gpt-responses-otherwise-chat") {
		return /^gpt-/i.test(id) ? "openai-responses" : "openai-completions";
	}
	return undefined;
}

function buildModel(config: ProviderConfig, id: string, api: ApiId): any {
	const hit = findCatalogEntry(id, api);
	const meta = hit?.model;
	const suffix = id.includes(":") ? id.slice(id.indexOf(":") + 1) : "";
	const model: any = {
		id,
		name: meta?.name ? (suffix ? `${meta.name} (${suffix})` : meta.name) : id,
		api,
		provider: config.id,
		baseUrl: `${config.root}${API_PATH[api]}`,
		reasoning: meta?.reasoning === true,
		input: Array.isArray(meta?.input) && meta.input.length > 0 ? [...meta.input] : ["text"],
		cost: meta?.cost
			? { ...meta.cost, ...(meta.cost.tiers ? { tiers: meta.cost.tiers.map((tier: any) => ({ ...tier })) } : {}) }
			: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
		contextWindow: typeof meta?.contextWindow === "number" && meta.contextWindow > 0 ? meta.contextWindow : 128_000,
		maxTokens: typeof meta?.maxTokens === "number" && meta.maxTokens > 0 ? meta.maxTokens : 16_384,
		type: "chat",
	};
	if (model.reasoning && meta?.thinkingLevelMap && meta.api === api) {
		model.thinkingLevelMap = { ...meta.thinkingLevelMap };
	}
	return model;
}

function toModels(config: ProviderConfig, payload: unknown): any[] {
	const data = (payload as { data?: unknown })?.data;
	if (!Array.isArray(data)) throw new Error(`${config.id} /v1/models: unexpected response shape`);
	const seen = new Set<string>();
	const models: any[] = [];
	for (const entry of data as GatewayModel[]) {
		if (typeof entry?.id !== "string" || !entry.id || seen.has(entry.id)) continue;
		const apis = new Set(
			(Array.isArray(entry.support_apis) ? entry.support_apis : [])
				.map((api) => (typeof api?.id === "string" ? api.id : ""))
				.filter(Boolean),
		);
		const api = chooseApi(config, entry.id, apis);
		if (!api) continue;
		seen.add(entry.id);
		models.push(buildModel(config, entry.id, api));
	}
	models.sort((a, b) => a.id.localeCompare(b.id));
	return models;
}

async function fetchModels(config: ProviderConfig, key: string, signal: AbortSignal, timeoutMs: number): Promise<any[]> {
	const response = await fetch(`${config.root}/v1/models`, {
		headers: { Authorization: `Bearer ${key}`, Accept: "application/json", ...config.headers },
		signal: AbortSignal.any([signal, AbortSignal.timeout(timeoutMs)]),
	});
	if (!response.ok) throw new Error(`${config.id} /v1/models failed: HTTP ${response.status}`);
	const models = toModels(config, await response.json());
	if (models.length === 0) throw new Error(`${config.id} /v1/models returned no usable models`);
	return models;
}

function resolveKey(credential: any): string | undefined {
	if (credential?.type === "api_key" && typeof credential.key === "string" && credential.key) return credential.key;
	return undefined;
}

function isOffline(): boolean {
	const flag = process.env.PI_OFFLINE;
	return process.argv.includes("--offline") || (flag !== undefined && flag !== "" && flag !== "0" && flag !== "false");
}

/** Re-apply the per-api path when pi's models.json layer reset baseUrl to the bare origin. */
function withApiBaseUrl(model: any): any {
	const path = API_PATH[model.api as ApiId];
	if (!path || typeof model.baseUrl !== "string") return model;
	try {
		const url = new URL(model.baseUrl);
		if (url.pathname !== "/" && url.pathname !== "") return model;
	} catch {
		return model;
	}
	return { ...model, baseUrl: `${model.baseUrl.replace(/\/+$/, "")}${path}` };
}

// ModelsProxy session affinity (wiki IrFxw4GaMiTLQxkVo8Qc2e08nab): the gateway reads `X-Session-Id`
// first. pi sends no session header for anthropic-messages / openai-completions unless
// sendSessionAffinityHeaders is set, and the default header name (`x-session-affinity`) is not
// recognised; the "openrouter" format sends `x-session-id: <pi sessionId>`. openai-responses
// already sends `session_id` + body `prompt_cache_key`. Explicit compat values win.
const SESSION_HEADER_APIS = new Set(["anthropic-messages", "openai-completions"]);

function withSessionAffinity(model: any): any {
	if (!SESSION_HEADER_APIS.has(model.api)) return model;
	const compat = model.compat ?? {};
	if (compat.sendSessionAffinityHeaders !== undefined && compat.sessionAffinityFormat !== undefined) return model;
	return {
		...model,
		compat: { sendSessionAffinityHeaders: true, sessionAffinityFormat: "openrouter", ...compat },
	};
}

function streamsFor(api: string): any {
	return getApiProvider(api as any) ?? FALLBACK_STREAMS[api as ApiId]?.();
}

function dispatch(config: ProviderConfig, model: any, run: (streams: any, model: any) => any): any {
	const streams = streamsFor(model.api);
	if (!streams) {
		return lazyStream(model, async () => {
			throw new Error(`Provider ${config.id} has no API implementation for "${model.api}"`);
		});
	}
	let requestModel = withApiBaseUrl(model);
	// Built-in APIs merge model.headers above their default UA, then options.headers above
	// model.headers. Apply here too so cache restores and models.json overlays retain the UA.
	if (config.headers) requestModel = { ...requestModel, headers: { ...config.headers, ...requestModel.headers } };
	if (config.sessionAffinity) requestModel = withSessionAffinity(requestModel);
	return run(streams, requestModel);
}

// On /reload pi re-registers providers and emits session_start before the async snapshot restore
// publishes, so extensions that validate models at session_start (pi-memory's dream check) would
// see an empty provider. Seed synchronously from the same snapshot; refreshModels still replaces it.
function readSnapshot(providerId: string): any[] {
	try {
		const store = JSON.parse(readFileSync(join(getAgentDir(), "models-store.json"), "utf8"));
		const models = store?.[providerId]?.models;
		return Array.isArray(models)
			? models.filter((model: any) => model?.provider === providerId && typeof model.id === "string")
			: [];
	} catch {
		return [];
	}
}

function createProvider(config: ProviderConfig): any {
	let dynamicModels: any[] = readSnapshot(config.id);

	return {
		id: config.id,
		name: config.name,
		baseUrl: config.root,
		headers: config.headers,
		auth: { apiKey: envApiKeyAuth(`${config.name} API key`, []) },
		getModels: () => dynamicModels,
		getAllModels: () => dynamicModels,
		refreshModels: async (context: any) => {
			const stored = context.stored;
			const restored = Array.isArray(stored?.models)
				? stored.models.filter((model: any) => model?.provider === config.id && typeof model.id === "string")
				: [];
			if (restored.length > 0) {
				const ok = await context.publish({ update: () => (dynamicModels = restored) });
				if (!ok) return;
			}
			if (context.signal.aborted) return;

			let timeoutMs = NETWORK_TIMEOUT_MS;
			if (!context.allowNetwork) {
				// Cache-only phase: bootstrap once when there is no snapshot at all.
				if (restored.length > 0 || isOffline()) return;
				timeoutMs = BOOTSTRAP_TIMEOUT_MS;
			} else if (
				!context.force &&
				restored.length > 0 &&
				typeof stored?.checkedAt === "number" &&
				Date.now() - stored.checkedAt < REFRESH_INTERVAL_MS
			) {
				return;
			}

			const key = resolveKey(context.credential);
			if (!key) return;
			let models: any[];
			try {
				models = await fetchModels(config, key, context.signal, timeoutMs);
			} catch (error) {
				// Bootstrap failures stay silent (fail open); network-phase failures are reported
				// by pi as a refresh error while the previous list stays in place.
				if (!context.allowNetwork || context.signal.aborted) return;
				throw error;
			}
			if (context.signal.aborted) return;
			await context.publish({
				persist: { models, checkedAt: Date.now() },
				update: () => (dynamicModels = models),
			});
		},
		stream: (model: any, ctx: any, options: any) => dispatch(config, model, (s, m) => s.stream(m, ctx, options)),
		streamSimple: (model: any, ctx: any, options: any) => dispatch(config, model, (s, m) => s.streamSimple(m, ctx, options)),
	};
}

export default function (pi: ExtensionAPI) {
	for (const config of PROVIDERS) {
		try {
			pi.registerProvider(createProvider(config));
		} catch {
			// Fail open per provider: other gateways and any models.json models still work.
		}
	}
}
