<!-- CherryHQ__cherry-studio@5644b00 dry-reviewer; verbatim final answer -->
## DRY findings

- severity: Medium
  category: dry.duplication
  file: src/renderer/src/middleware/extractReasoningMiddleware.ts
  line: 21
  title: The new `<think>` extractor is a second parser alongside ThoughtProcessor/thinkTagProcessor, and the old one is left with no callers
  evidence: |
    wrapGenerate: async ({ doGenerate }: { doGenerate: () => Promise<{ text: string } & Record<string, any>> }) => {
      const { text: rawText, ...rest } = await doGenerate()
      ...
      const regexp = new RegExp(`${openingTag}(.*?)${closingTag}`, 'gs')
      const matches = Array.from(text.matchAll(regexp))
  evidence_refs:
    - src/renderer/src/utils/formats.ts:130
    - src/renderer/src/utils/formats.ts:138
    - src/renderer/src/providers/AiProvider/BaseProvider.ts:238
    - src/renderer/src/providers/AiProvider/OpenAIProvider.ts:744
    - src/renderer/src/providers/AiProvider/OpenAIProvider.ts:816
    - src/renderer/src/providers/AiProvider/OpenAIProvider.ts:868
  impact: |
    The repo now has three separate ways to parse `<think>…</think>`:
    1. `thinkTagProcessor` in formats.ts:130-169, reached through `BaseProvider.findThinkingProcessor` at BaseProvider.ts:238. A repo grep finds no callers left for `findThinkingProcessor` after this diff.
    2. The new middleware, with both `wrapGenerate` and `wrapStream`. `wrapGenerate` is never called.
    3. Inline copies inside the same provider file: the `/^<think>(.*?)<\/think>/s` strip in `summaries` (OpenAIProvider.ts:816) and `summaryForSearch` (OpenAIProvider.ts:868), plus a hand-rolled `<think>`/`</think>` skip loop in `translate` (OpenAIProvider.ts:744-764).
    Fixes to tag handling (whitespace, unclosed tags, `startWithReasoning`) will land in one parser and not the others. The `glmZeroPreviewProcessor` `###Thinking/###Response` path is also orphaned by the same diff.
  remedy: |
    Make the middleware the only `<think>` parser.
    - Route `summaries`, `summaryForSearch` and `translate` through `extractReasoningMiddleware(...).wrapGenerate` / `wrapStream`. Or drop `wrapGenerate` and reuse `thinkTagProcessor.process` for the non-streaming strips.
    - Delete the now-unused `findThinkingProcessor` (BaseProvider.ts:234-243) and, if nothing else needs them, `thinkTagProcessor`/`glmZeroPreviewProcessor` (formats.ts:102-169).
    - Do not keep both parsers.
  confidence: high
  overlap_hints: [craft.abstraction, ai-antipatterns.ignored-convention, correctness]

- severity: Low
  category: dry.missing-abstraction
  file: src/renderer/src/middleware/convertLinksMiddleware.ts
  line: 4
  title: Both new middlewares copy the same wrapStream/TransformStream text-delta scaffolding and the same `@ts-expect-error` cast
  evidence: |
    export function convertLinksMiddleware<T extends { type: string } = { type: string; textDelta: string }>() {
      return {
        wrapStream: async ({
          doStream
        }: {
          doStream: () => Promise<{ stream: ReadableStream<T> } & Record<string, any>>
        }) => {
          const { stream, ...rest } = await doStream()
          return {
            stream: stream.pipeThrough(
              new TransformStream<T, T>({
                transform: (chunk, controller) => {
                  if (chunk.type === 'text-delta') {
                    ...
                      // @ts-expect-error: textDelta 只在 text-delta chunk 上
  evidence_refs:
    - src/renderer/src/middleware/extractReasoningMiddleware.ts:12
    - src/renderer/src/middleware/extractReasoningMiddleware.ts:43
    - src/renderer/src/middleware/extractReasoningMiddleware.ts:56
    - src/renderer/src/middleware/extractReasoningMiddleware.ts:62
    - src/renderer/src/providers/AiProvider/OpenAIProvider.ts:64
  impact: |
    The two files repeat the same pieces:
    - the generic `T extends { type: string } = { type: string; textDelta: string }`
    - the `doStream` signature type
    - the `{ stream, ...rest }` destructure and re-spread
    - the `pipeThrough(new TransformStream<T,T>)` plus pass-through for chunks that are not `text-delta`
    - the `@ts-expect-error` workaround for `textDelta`
    The chunk shape is also defined three times, with `OpenAIStreamChunk` at OpenAIProvider.ts:64 being the third. Each new middleware will copy this again, and a typing fix in one copy will not reach the others.
  remedy: |
    Extract one shared `StreamMiddleware<T>` type and a `TextDeltaChunk` type, ideally reusing `OpenAIStreamChunk` or moving it into the middleware folder. Add a small `mapTextDelta(stream, fn)` helper next to `src/renderer/src/utils/stream.ts`. `convertLinksMiddleware` then becomes a one-line call to that helper, and the `@ts-expect-error` goes away once the types are correct.
  confidence: medium
  overlap_hints: [craft.abstraction, api-contract.type-boundary]

- severity: Low
  category: dry.copy-paste
  file: src/renderer/src/providers/AiProvider/OpenAIProvider.ts
  line: 598
  title: The rewritten finish branch repeats the LLM_WEB_SEARCH_COMPLETE onChunk literal four times
  evidence: |
    if (delta?.annotations) {
      onChunk({
        type: ChunkType.LLM_WEB_SEARCH_COMPLETE,
        llm_web_search: {
          results: delta.annotations,
          source: WebSearchSource.OPENAI
        }
      } as LLMWebSearchCompleteChunk)
    }
    ...
    if (isEnabledWebSearch && isZhipuModel(model) && finishReason === 'stop' && rawChunk?.web_search) {
      onChunk({
        type: ChunkType.LLM_WEB_SEARCH_COMPLETE,
        llm_web_search: {
          results: rawChunk.web_search,
          source: WebSearchSource.ZHIPU
  evidence_refs:
    - src/renderer/src/providers/AiProvider/OpenAIProvider.ts:610
    - src/renderer/src/providers/AiProvider/OpenAIProvider.ts:620
    - src/renderer/src/providers/AiProvider/OpenAIProvider.ts:629
    - src/renderer/src/providers/AiProvider/GeminiProvider.ts:471
  impact: |
    The diff rewrote and re-indented this block. It still has four copies of the same chunk literal, plus a fifth in GeminiProvider.ts:471, that differ only in `results` and `source`. Any change to the chunk's shape or cast has to be made five times. This duplication existed before the diff, which carried it forward rather than introducing it.
  remedy: |
    While the block is being rewritten anyway, add
    `const emitWebSearch = (results, source: WebSearchSource) => onChunk({ type: ChunkType.LLM_WEB_SEARCH_COMPLETE, llm_web_search: { results, source } } as LLMWebSearchCompleteChunk)`
    and call it from the four branches. If it lives on BaseProvider as a protected helper, GeminiProvider.ts:471 can use it too.
  confidence: high
  overlap_hints: [craft.code-judo]

Checked and not flagged:
- `getPotentialIndex.ts` and the middleware are vendored from vercel/ai. `ai` is not in package.json or node_modules, so there is no existing dependency to reuse.
- `stream.ts`: the repo has no existing ReadableStream or async-iterator helper.

## Files examined
examined: [src/renderer/src/middleware/convertLinksMiddleware.ts, src/renderer/src/middleware/extractReasoningMiddleware.ts, src/renderer/src/providers/AiProvider/BaseProvider.ts, src/renderer/src/providers/AiProvider/OpenAIProvider.ts, src/renderer/src/utils/getPotentialIndex.ts, src/renderer/src/utils/stream.ts]
not_examined: []
