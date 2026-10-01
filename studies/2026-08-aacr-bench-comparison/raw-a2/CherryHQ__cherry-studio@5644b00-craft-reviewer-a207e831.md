<!-- CherryHQ__cherry-studio@5644b00 craft-reviewer; verbatim final answer -->
- severity: Medium
  category: craft.code-judo
  file: src/renderer/src/providers/AiProvider/OpenAIProvider.ts
  line: 534
  title: The Vercel-style middleware envelope (wrapStream/doStream) and three stream conversions sit on the hot streaming path, but nothing runs a middleware pipeline
  evidence: |
    const { stream: reasoningStream } = await extractReasoningMiddleware<OpenAIStreamChunk>({
      tagName: reasoningTag.tagName,
      separator: reasoningTag.separator,
      startWithReasoning: false
    }).wrapStream({
      doStream: async () => ({
        stream: asyncGeneratorToReadableStream(openAIChunkToTextDelta(stream))
      })
    })

    const { stream: processedStream } = await convertLinksMiddleware<OpenAIStreamChunk>().wrapStream({
      doStream: async () => ({ stream: reasoningStream })
    })

    for await (const chunk of readableStreamAsyncIterable(processedStream)) {
  evidence_refs: [src/renderer/src/utils/stream.ts:1, src/renderer/src/utils/stream.ts:14, src/renderer/src/middleware/convertLinksMiddleware.ts:5, src/renderer/src/middleware/extractReasoningMiddleware.ts:43]
  impact: Each transform has to be wrapped as `{ wrapStream: ({ doStream }) => Promise<{ stream } & Record<string, any>> }`. The caller then builds fake `doStream` thunks by hand, turns an AsyncGenerator into a ReadableStream, pipes it through TransformStreams, and turns it back into an AsyncIterable. The repo has no AI SDK middleware runner (`ai`/`@ai-sdk` is not a dependency), so the envelope only adds indirection, `any`-typed `...rest` plumbing, and two adapter helpers (`stream.ts`) that nothing else uses.
  remedy: Collapse the pipeline into plain async-generator transforms composed directly, e.g. `for await (const c of convertLinks(extractReasoning(openAIChunkToTextDelta(stream), opts)))`, where each transform is `async function*(src: AsyncIterable<OpenAIStreamChunk>)`. This deletes `utils/stream.ts`, the wrapStream/doStream envelope, the `Record<string, any>` rest spreading and the `await` on synchronous wrappers. If the AI SDK middleware shape is planned for later, adopt the real `ai` package then, not a hand-copied imitation.
  confidence: high
  overlap_hints: [ai-antipatterns.over-engineering, performance]

- severity: Medium
  category: craft.boundary
  file: src/renderer/src/providers/AiProvider/OpenAIProvider.ts
  line: 64
  title: The new normalized chunk union uses `any` and passes the raw provider chunk through, so downstream code still parses the raw OpenAI and vendor fields
  evidence: |
    export type OpenAIStreamChunk =
      | { type: 'reasoning' | 'text-delta'; textDelta: string }
      | { type: 'finish'; finishReason: any; usage: any; delta: any; chunk: any }
    ...
    const rawChunk = chunk.chunk
    const currentTime = new Date().getTime()
    if (!isEmpty(finishReason)) {
    ...
    const citations = rawChunk.citations
    ...
    rawChunk?.web_search
    ...
    rawChunk?.search_info?.search_results
  impact: The normalization step (`openAIChunkToTextDelta`) is meant to be the boundary, but the `finish` variant carries `delta: any` and `chunk: any`. The consumer reaches back into vendor-specific raw fields (Perplexity `citations`, Zhipu `web_search`, Hunyuan `search_info`, OpenAI `annotations`), so vendor parsing is split across two places. The `finish` case re-checks `!isEmpty(finishReason)` even though the generator only yields `finish` when that already holds, and it shadows the outer `currentTime`. The type is exported but only used in this file.
  remedy: Move vendor web-search extraction into the normalizer and give the union a typed variant, e.g. `{ type: 'web-search'; results: unknown; source: WebSearchSource }` plus `{ type: 'finish'; finishReason: string; usage?: Usage }`. The consumer then becomes a flat switch with no `rawChunk` access, the redundant `isEmpty` guard goes away, and so does the shadowed `currentTime`. Drop the `export` unless another module needs the type.
  confidence: high
  overlap_hints: [api-contract.type-safety]

- severity: Medium
  category: craft.spaghetti
  file: src/renderer/src/providers/AiProvider/OpenAIProvider.ts
  line: 638
  title: End-of-stream finalization (tool calls, recursive re-stream, BLOCK_COMPLETE) moved from after the loop into the `finish` case of the per-chunk switch
  evidence: |
            // 5. 工具调用和最终 block_complete
            await processToolUses(content, idx)
            onChunk({
              type: ChunkType.BLOCK_COMPLETE,
              response: {
                usage: lastUsage,
  impact: Finalizing the block now depends on a `finish` chunk arriving, not on the stream ending. If the pause check `break`s in `openAIChunkToTextDelta`, or the provider never sends a `finish_reason`, no BLOCK_COMPLETE is sent. `processToolUses` calls `processStream` recursively while the outer `for await` over the piped ReadableStream is still open, so stream lifetimes nest inside a switch case. The base version ran this code after the loop, which is the structurally correct place.
  remedy: Keep the switch for per-chunk dispatch only (`finish` just records finishReason, usage and timing). Move `processToolUses` and the BLOCK_COMPLETE emission back after the `for await` loop so they run however the stream ends.
  confidence: high
  overlap_hints: [correctness.error-path]

- severity: Medium
  category: craft.abstraction
  file: src/renderer/src/middleware/convertLinksMiddleware.ts
  line: 4
  title: A per-stream middleware factory wraps `convertLinks`, which keeps module-global state, and never resets it; the provider-specific converters are left with no production callers
  evidence: |
    export function convertLinksMiddleware<T extends { type: string } = { type: string; textDelta: string }>() {
      ...
                  textDelta: convertLinks(chunk.textDelta)
  evidence_refs: [src/renderer/src/utils/linkConverter.ts:2, src/renderer/src/utils/linkConverter.ts:4, src/renderer/src/utils/linkConverter.ts:6, src/renderer/src/utils/linkConverter.ts:123, src/renderer/src/utils/linkConverter.ts:25, src/renderer/src/utils/linkConverter.ts:60, src/renderer/src/utils/linkConverter.ts:269]
  impact: A factory called once per stream implies each stream gets its own state. In fact `linkCounter`, `buffer` and `urlToCounterMap` are module-level, and the middleware never passes `resetCounter` (the old code passed `isFirstChunk`), so counters and partial buffers leak across streams and across recursive tool-call streams. The old enableWebSearch-gated dispatch to `convertLinksToOpenRouter` / `convertLinksToZhipu` / `convertLinksToHunyuan` was removed without moving it anywhere. Those three exports are now dead production code, kept alive only by `utils/__tests__/linkConverter.test.ts`.
  remedy: Make the state ownership explicit. Either turn linkConverter into a `createLinkConverter(kind, webSearch?)` that returns a closure with its own counter and buffer, created inside the transform per stream, or at least call `convertLinks(text, true)` on the first text chunk. Then pick one: carry the provider dispatch into the transform (which can take the converter as a parameter), or delete the orphaned provider converters and their tests in the same PR.
  confidence: high
  overlap_hints: [correctness.side-effect, dry.duplication]

- severity: Medium
  category: craft.spaghetti
  file: src/renderer/src/providers/AiProvider/OpenAIProvider.ts
  line: 502
  title: `getAppropriateTag` has three branches that all return the same value, its second tag is never used, and it is redefined on every processStream call
  evidence: |
      const reasoningTags = [
        { tagName: 'think', separator: '\n' },
        { tagName: 'reasoning', separator: '\n' }
      ]
      const getAppropriateTag = (model: Model | undefined) => {
        if (!model) return reasoningTags[0]
        if (model.id.includes('claude')) return reasoningTags[0]
        return reasoningTags[0]
      }
      const reasoningTag = getAppropriateTag(model)
  impact: The code looks like a per-model selection mechanism, but it always returns `{ tagName: 'think', separator: '\n' }`. Readers have to trace three branches to learn that, and the `'reasoning'` entry and the `claude` special case suggest support that does not exist. It is also re-allocated on each recursive tool-call pass. Meanwhile the real per-model knowledge, `glmZeroPreviewProcessor` (`###Thinking`/`###Response`), is not wired in.
  remedy: Delete `reasoningTags` and `getAppropriateTag` and pass `{ tagName: 'think' }` directly; `separator` and `startWithReasoning` are already the defaults. If per-model tags are really needed, put a typed `model -> tagName` map next to the model config in `config/models.ts`, not inline in processStream.
  confidence: high
  overlap_hints: [ai-antipatterns.over-engineering]

- severity: Low
  category: craft.abstraction
  file: src/renderer/src/middleware/extractReasoningMiddleware.ts
  line: 21
  title: The copied `wrapGenerate` (about 20 lines) is never called; the non-streaming path does not use it
  evidence: |
    wrapGenerate: async ({ doGenerate }: { doGenerate: () => Promise<{ text: string } & Record<string, any>> }) => {
      const { text: rawText, ...rest } = await doGenerate()
  impact: This is dead vendored code with its own regex and a backward splice loop, and nothing exercises it. The non-streaming branch of processStream (OpenAIProvider.ts:469) emits `message.content` without extracting `<think>`, so the generate half is neither used nor tested.
  remedy: Delete `wrapGenerate`. If non-streaming reasoning extraction is wanted, call a plain `extractReasoning(text, tagName)` function from the non-streaming branch.
  confidence: high
  overlap_hints: [ai-antipatterns.over-engineering]

- severity: Low
  category: craft.boundary
  file: src/renderer/src/middleware/extractReasoningMiddleware.ts
  line: 12
  title: The generic `T extends { type: string }` does not express the `textDelta` invariant the code relies on, so `@ts-expect-error` is needed to compile
  evidence: |
    export function extractReasoningMiddleware<T extends { type: string } = { type: string; textDelta: string }>({
    ...
              // @ts-expect-error: textDelta 只在 text-delta/reasoning chunk 上
              buffer += chunk.textDelta
  evidence_refs: [src/renderer/src/middleware/convertLinksMiddleware.ts:4, src/renderer/src/middleware/convertLinksMiddleware.ts:19]
  impact: Both middlewares claim to be generic but only work for chunk types that have `textDelta` on `'text-delta'`, and they emit `type: 'reasoning'` into `T` without checking. The suppressions hide the real contract, so any change to the chunk shape compiles silently.
  remedy: Constrain the generic to a discriminated union, e.g. `T extends { type: string } | { type: 'text-delta' | 'reasoning'; textDelta: string }`, and narrow on `chunk.type === 'text-delta'`. Simpler still, type the transforms directly against `OpenAIStreamChunk`, their only consumer, and drop both `@ts-expect-error`s.
  confidence: medium
  overlap_hints: [api-contract.type-safety]

- severity: Low
  category: craft.code-judo
  file: src/renderer/src/providers/AiProvider/BaseProvider.ts
  line: 238
  title: The PR removes `handleThinkingTags` but leaves its partner `findThinkingProcessor` and the ThoughtProcessor imports, which now have zero callers
  evidence: |
      protected findThinkingProcessor(chunkText: string, model: Model | undefined): ThoughtProcessor | undefined {
        if (!model) return undefined

        const processors: ThoughtProcessor[] = [thinkTagProcessor, glmZeroPreviewProcessor]
  evidence_refs: [src/renderer/src/utils/formats.ts:102, src/renderer/src/utils/formats.ts:107, src/renderer/src/utils/formats.ts:130]
  impact: The new tag-extraction transform replaces the old ThoughtProcessor approach, but only half of it is deleted. The base class still offers a protected API no subclass calls, and `formats.ts` still exports `thinkTagProcessor` and `glmZeroPreviewProcessor` for that dead method alone. Readers now see two competing reasoning-extraction mechanisms.
  remedy: Finish the migration. Delete `findThinkingProcessor` and its import in BaseProvider, plus `ThoughtProcessor`, `thinkTagProcessor` and `glmZeroPreviewProcessor` in `utils/formats.ts`. If GLM `###Thinking` support is still required, port it as a tag option of the new transform.
  confidence: high
  overlap_hints: [dry.duplication]

- severity: Low
  category: craft.spaghetti
  file: src/renderer/src/providers/AiProvider/OpenAIProvider.ts
  line: 495
  title: Seven loose timing and flag variables with overlapping guards; `time_first_token_millsec` and `time_first_content_millsec` are only ever read as "is zero" guards
  evidence: |
      let isFirstChunk = true
      let time_first_token_millsec = 0
      let time_first_token_millsec_delta = 0
      let time_first_content_millsec = 0
      let time_thinking_start = 0
    ...
            if (isFirstChunk) {
              isFirstChunk = false
              if (time_first_token_millsec === 0) {
  impact: The guards overlap: `isFirstChunk` plus `time_first_token_millsec === 0`, and `time_thinking_start` duplicates `time_first_token_millsec` on the reasoning path. Tracing the metrics means following several mutable variables across switch cases. The rewrite was a chance to simplify this and instead it was reshuffled.
  remedy: Replace the variables with a small `createStreamMetrics(start)` tracker that exposes `markFirstToken()`, `markThinkingStart()`, `markFirstContent()` and `markComplete()` and a `toMetrics()` that returns the BLOCK_COMPLETE metrics object. That deletes `isFirstChunk`, `time_first_token_millsec` and `time_first_content_millsec` as separate state.
  confidence: medium
  overlap_hints: []

- severity: Nitpick
  category: craft.boundary
  file: src/renderer/src/middleware/extractReasoningMiddleware.ts
  line: 3
  title: A new top-level `src/renderer/src/middleware/` directory holds transforms used only by OpenAIProvider, and imports use a relative path instead of the repo's `@renderer` alias
  evidence: |
    import { getPotentialStartIndex } from '../utils/getPotentialIndex'
  impact: The directory name suggests an app-wide middleware layer, but these are provider stream transforms. Their single helper (`utils/getPotentialIndex.ts`) sits in generic utils with only one consumer. The relative import breaks the alias convention used by the sibling file (`@renderer/utils/linkConverter`).
  remedy: Co-locate them, e.g. `providers/AiProvider/streamTransforms/`, with `getPotentialStartIndex` moved inside the reasoning transform module. Use `@renderer/...` imports.
  confidence: medium
  overlap_hints: []

Size check: OpenAIProvider.ts is 1199 lines, down from 1260 at the merge base. It was already over 1k before this PR and the PR shrinks it, so there is no `craft.size` finding.

## Files examined
examined: [src/renderer/src/middleware/convertLinksMiddleware.ts, src/renderer/src/middleware/extractReasoningMiddleware.ts, src/renderer/src/providers/AiProvider/BaseProvider.ts, src/renderer/src/providers/AiProvider/OpenAIProvider.ts, src/renderer/src/utils/getPotentialIndex.ts, src/renderer/src/utils/stream.ts]
not_examined: []

Notes on depth: I read the full diff for all six files. For OpenAIProvider.ts I also read lines 380-670 at HEAD; the rest of that file I know only from the diff hunks and grep. For BaseProvider.ts I read lines 1-40 and 225-244 plus the diff. For context I also read parts of src/renderer/src/utils/linkConverter.ts and src/renderer/src/utils/formats.ts, and I grepped the repo for callers of the orphaned helpers.
