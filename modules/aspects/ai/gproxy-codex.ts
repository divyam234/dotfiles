import { streamSimple } from "@oh-my-pi/pi-ai";
import { getBundledModels } from "@oh-my-pi/pi-catalog/models";
import { createOpenAICodexCompatibilityMetadata } from "@oh-my-pi/pi-ai/providers/openai-codex-responses";
import { fetchCodexModels } from "@oh-my-pi/pi-catalog/discovery/codex";
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

const baseUrl = "@GPROXY_BASE_URL@";
const api = "gproxy-codex-responses";

export default function (pi: ExtensionAPI) {
  // CLI model selection can precede extension registration. Rebind the
  // selected model to its runtime overlay once the session is available.
  pi.on("session_start", async (_event, ctx) => {
    if (ctx.model?.provider !== "openai-codex") return;
    const model = ctx.modelRegistry.find("openai-codex", ctx.model.id);
    if (!model || model.api !== api || !(await pi.setModel(model))) {
      throw new Error("Could not select the gproxy Code Mode transport");
    }
  });
  const models = getBundledModels("openai-codex")
    .filter(model => model.api === "openai-codex-responses")
    .filter(model => !model.kind || model.kind === "chat" || model.kind === "tiny")
    .map(model => ({ ...model, api, baseUrl }));

  pi.registerProvider("openai-codex", {
    baseUrl,
    api,
    apiKey: "OPENAI_API_KEY",
    models,
    async fetchDynamicModels(key) {
      if (!key) throw new Error("Gproxy Code Mode requires OPENAI_API_KEY");
      const result = await fetchCodexModels({ accessToken: key, baseUrl });
      if (!result || result.rejectedStatus) {
        throw new Error("Gproxy Codex model discovery failed");
      }
      return result.models.filter(model => !model.kind || model.kind === "chat" || model.kind === "tiny")
        .map(model => ({ ...model, api, baseUrl }));
    },
    streamSimple(model, context, options) {
      const metadata = createOpenAICodexCompatibilityMetadata({
        ...options,
        requestKind: "turn",
      });
      const turnMetadata = JSON.parse(metadata.headers["x-codex-turn-metadata"]);
      if (options?.toolNamespacesInfo !== undefined) {
        turnMetadata.tool_namespaces_info = options.toolNamespacesInfo;
      }
      return streamSimple(
        { ...model, provider: "openai", api: "openai-responses", baseUrl, compat: model.compat ?? {} },
        context,
        {
          ...options,
          apiKey: options?.apiKey ?? process.env.OPENAI_API_KEY,
          headers: { ...options?.headers, ...metadata.headers },
          async onPayload(payload, requestModel) {
            const replacement = await options?.onPayload?.(payload, requestModel);
            const body = replacement ?? payload;
            body.client_metadata = {
              ...body.client_metadata,
              ...metadata.clientMetadata,
              "x-codex-turn-metadata": JSON.stringify(turnMetadata),
            };
            return body;
          },
        },
      );
    },
  });
}
