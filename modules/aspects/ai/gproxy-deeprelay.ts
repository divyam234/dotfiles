// Discovers deeprelay models from the gproxy OpenAI-compatible route and
// injects them into the deeprelay provider. OpenCode only discovers models
// automatically for Ollama, LM Studio, and vLLM, so this plugin fills the gap
// for arbitrary OpenAI-compatible gateways.
const SKIP = /image|flux|seedream|seedance|vidu|wan2|qwen-image|pixverse|embedding|t2v|happyhorse|gpt-image|audio/i
const REFRESH = 30_000

export default {
  id: "gproxy-deeprelay",
  setup: (ctx) => {
    const baseURL = "@GPROXY_BASE_URL@"
    const providerID = "deeprelay"

    const fetchModels = async () => {
      const key = process.env.OPENAI_API_KEY
      const res = await fetch(`${baseURL}/models`, {
        headers: key ? { Authorization: `Bearer ${key}` } : {},
        signal: AbortSignal.timeout(15000),
      })
      if (!res.ok) return {}
      const json = await res.json()
      const out = {}
      for (const m of json.data ?? []) {
        const upstreamID = m.id ?? ""
        if (!upstreamID || SKIP.test(upstreamID)) continue
        // Upstream IDs carry the vendor prefix; OpenCode already scopes by provider.
        const id = upstreamID.replace(/^deeprelay\//, "")
        const params = m.supported_parameters ?? []
        const modalities = m.input_modalities ?? ["text"]
        out[id] = {
          name: m.display_name ?? id,
          tools: params.includes("tools"),
          vision: modalities.includes("image"),
          context: m.context_window ?? 131072,
          output: m.max_output_tokens ?? 32768,
        }
      }
      return out
    }

    let models = {}

    const refresh = async () => {
      try {
        models = await fetchModels()
        await ctx.provider.reload()
      } catch (error) {
        console.error(`[gproxy-deeprelay] model discovery failed: ${error?.message ?? error}`)
      }
    }

    const registration = ctx.provider.transform((providers) => {
      for (const [id, spec] of Object.entries(models)) {
        providers.models.update(providerID, id, (model) => {
          model.name = spec.name
          model.capabilities = {
            tools: spec.tools,
            temperature: true,
            input: ["text", ...(spec.vision ? ["image"] : [])],
            output: ["text"],
          }
          if (spec.context > 0) model.limit.context = spec.context
          if (spec.output > 0) model.limit.output = spec.output
        })
      }
    })

    const timer = setInterval(refresh, REFRESH)
    timer.unref?.()
    void refresh()

    return () => {
      clearInterval(timer)
      void registration?.dispose?.()
    }
  },
}
