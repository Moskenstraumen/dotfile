// Session-owned native agy transport; implementation lives outside extension autoload.
import { install } from "../lib/agy-bridge/controller.ts";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
export default function agyBridge(pi: ExtensionAPI) { install(pi); }
