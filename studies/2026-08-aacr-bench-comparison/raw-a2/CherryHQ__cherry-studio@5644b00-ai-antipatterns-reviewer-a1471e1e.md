<!-- CherryHQ__cherry-studio@5644b00 ai-antipatterns-reviewer; verbatim final answer -->
## AI-Antipatterns findings

- severity: High
  category: ai-antipatterns.ignored-convention
  file: src/renderer/src/middleware/convertLinksMiddleware.ts
  line: 20
  title: The wrapper calls the stateful `convertLinks` without `resetCounter`, on every response, and drops the provider-specific converters
  evidence: |
    if (chunk.type === 'text-delta') {
      controller.enqueue({
        ...chunk,
        // @ts-expect-error: textDelta 只在 text-delta chunk 上
        textDelta: convertLinks(chunk.textDelta)
      })
  impact: |
    Assumed: `convertLinks` is a pure per-chunk function that is safe on any text.
    Actual: it keeps module-level state (`linkCounter`, `buffer`, `urlToCounterMap`) and only clears it when `resetCounter` is true (src/renderer/src/utils/linkConverter.ts:2-6 and :123-128).
    The old caller passed `isFirstChunk` as `resetCounter` and only ran the converter when `assistant.enableWebSearch` was on. It also picked `convertLinks`, `convertLinksToOpenRouter`, `convertLinksToZhipu` or `convertLinksToHunyuan` from the provider (pre-change OpenAIProvider.ts, the "2. Text Content" block).
    Now the counter and buffer are never reset, so link numbers carry over between messages, and leftover buffered text from one stream is prepended to the next.
    The converter also now runs on every text delta of every model. Any `[` that does not start a full link (for example `arr[0]`) makes it hold back the rest of the text. Nothing flushes that held text at the end of the stream, so it is never shown.
    `convertLinksToOpenRouter`, `convertLinksToZhipu` and `convertLinksToHunyuan` are now referenced only by src/renderer/src/utils/__tests__/linkConverter.test.ts. Their production dispatch was silently removed.
  remedy: |
    Restore the existing contract. Gate on `assistant.enableWebSearch`, choose the converter per provider as before, and pass `resetCounter = true` on the first text delta. The simplest way is to do this inline in the consumer's `text-delta` case and delete `convertLinksMiddleware`.
  confidence: high
  evidence_refs: [src/renderer/src/utils/linkConverter.ts:2, src/renderer/src/utils/linkConverter.ts:123, src/renderer/src/utils/__tests__/linkConverter.test.ts:7]
  overlap_hints: [correctness.regression, correctness.side-effect]

- severity: Medium
  category: ai-antipatterns.over-engineering
  file: src/renderer/src/providers/AiProvider/OpenAIProvider.ts
  line: 534
  title: A copy of the vercel/ai middleware protocol (`wrapStream({ doStream })`) is rebuilt without the `ai` package, only to pipe one stream
  evidence: |
    const { stream: reasoningStream } = await extractReasoningMiddleware<OpenAIStreamChunk>({
      ...
    }).wrapStream({
      doStream: async () => ({
        stream: asyncGeneratorToReadableStream(openAIChunkToTextDelta(stream))
      })
    })
    const { stream: processedStream } = await convertLinksMiddleware<OpenAIStreamChunk>().wrapStream({
      doStream: async () => ({ stream: reasoningStream })
    })
    for await (const chunk of readableStreamAsyncIterable(processedStream)) {
  impact: |
    Assumed: the code plugs into a middleware system.
    Actual: `ai` / `@ai-sdk/*` are not in package.json (grep found no match), and nothing else in the repo uses `wrapStream` / `doStream`. The `{ doStream: async () => ({ stream }) } & Record<string, any>` ceremony exists only to match the upstream `LanguageModelV1Middleware` shape.
    The data goes through four format changes: async generator, then `ReadableStream` (new utils/stream.ts), then two `TransformStream`s, then a hand-written async iterable.
    That iterable's `readableStreamAsyncIterable` has no `return()`, so the reader is never released when the loop exits early.
  remedy: |
    Drop the fake middleware protocol. Either expose plain `TransformStream` factories (`createReasoningExtractor(tag)`) and `pipeThrough` them directly, or chain async generators end to end. Either way, `utils/stream.ts` and the `doStream` wrappers go away.
  confidence: high
  evidence_refs: [package.json, src/renderer/src/utils/stream.ts:1, src/renderer/src/utils/stream.ts:14]
  overlap_hints: [craft.abstraction]

- severity: Medium
  category: ai-antipatterns.over-engineering
  file: src/renderer/src/middleware/extractReasoningMiddleware.ts
  line: 21
  title: The `wrapGenerate` copied from vercel/ai is dead code with no caller
  evidence: |
    wrapGenerate: async ({ doGenerate }: { doGenerate: () => Promise<{ text: string } & Record<string, any>> }) => {
      const { text: rawText, ...rest } = await doGenerate()
  impact: |
    The only consumer (OpenAIProvider.ts:538) calls `.wrapStream`. A repo-wide grep finds `wrapGenerate` / `doGenerate` only at their definition.
    The non-stream path in OpenAIProvider (`!isSupportStreamOutput()`, around line 469) does not use it either. About 20 lines of upstream code were carried over without being adapted or used.
  remedy: Delete `wrapGenerate`. Add it back only when the non-stream path actually needs it.
  confidence: high
  overlap_hints: [craft.dead-code]

- severity: Medium
  category: ai-antipatterns.over-engineering
  file: src/renderer/src/middleware/convertLinksMiddleware.ts
  line: 4
  title: Generic type parameters are too loose, so the field access needs `@ts-expect-error`
  evidence: |
    export function convertLinksMiddleware<T extends { type: string } = { type: string; textDelta: string }>() {
    ...
                  // @ts-expect-error: textDelta 只在 text-delta chunk 上
                  textDelta: convertLinks(chunk.textDelta)
  impact: |
    The constraint `T extends { type: string }` leaves out `textDelta`, the one field the code reads, so the access has to be suppressed. The same pattern is at extractReasoningMiddleware.ts:12 and :62.
    The generic flexibility is never used: both are only instantiated with `OpenAIStreamChunk`, and the default `{ type: string; textDelta: string }` is never selected.
    The suppression also hides any real type error on that line. These two lines are the only `@ts-expect-error` uses in src/renderer/src (grep count 2), so the change goes against the codebase's typing practice.
  remedy: Type the transforms against the concrete `OpenAIStreamChunk`, or constrain to `T extends { type: string; textDelta?: string }`, and remove both `@ts-expect-error` lines.
  confidence: high
  evidence_refs: [src/renderer/src/middleware/extractReasoningMiddleware.ts:12, src/renderer/src/middleware/extractReasoningMiddleware.ts:62]
  overlap_hints: [api-contract.type-boundary, craft.type-boundary]

- severity: Medium
  category: ai-antipatterns.over-engineering
  file: src/renderer/src/providers/AiProvider/OpenAIProvider.ts
  line: 502
  title: The `reasoningTags` table and `getAppropriateTag` are a dispatch layer where every branch returns the same value
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
  impact: |
    The `reasoning` entry is never selected, and the `claude` branch cannot change the result. This is room for an imaginary future case.
    Meanwhile the repo already has model-aware reasoning detection in `ThoughtProcessor` (`thinkTagProcessor`, `glmZeroPreviewProcessor` in src/renderer/src/utils/formats.ts:102-130, chosen by `BaseProvider.findThinkingProcessor`). The new code ignores it.
    The removed `###Response` handling for GLM-Zero (in the old `isReasoningJustDone`) has no replacement.
  remedy: Pass `{ tagName: 'think' }` directly and delete the table and the selector. If per-model tags are really needed, base them on the existing ThoughtProcessor registry.
  confidence: high
  evidence_refs: [src/renderer/src/utils/formats.ts:107, src/renderer/src/utils/formats.ts:130, src/renderer/src/providers/AiProvider/BaseProvider.ts:238]
  overlap_hints: [craft.dead-code, correctness.regression]

- severity: Low
  category: ai-antipatterns.over-engineering
  file: src/renderer/src/providers/AiProvider/OpenAIProvider.ts
  line: 592
  title: The `isEmpty(finishReason)` re-check can never be false, and `currentTime` is declared a second time
  evidence: |
    case 'finish': {
      ...
      const currentTime = new Date().getTime()
      if (!isEmpty(finishReason)) {
  impact: |
    The generator only yields `finish` after the same `!isEmpty(finishReason)` check (line 526), so this guard is always true. The `currentTime` declared here shadows the one at line 550.
    Both are leftovers from the old loop, kept without understanding the new invariant.
    Related, owned by correctness: `processToolUses` and `BLOCK_COMPLETE` now run only inside this case. If the user pauses or the stream ends without a `finish_reason`, the block is never completed.
  remedy: Remove the redundant guard and the inner `currentTime`. Move `processToolUses` and `BLOCK_COMPLETE` after the loop, as they were before.
  confidence: high
  overlap_hints: [correctness.error-path]

- severity: Low
  category: ai-antipatterns.over-engineering
  file: src/renderer/src/providers/AiProvider/OpenAIProvider.ts
  line: 63
  title: Leftover numbered step comments ("1." twice, then 2, 3, 5) and an exported union typed with `any`
  evidence: |
    // 1. 定义联合类型
    export type OpenAIStreamChunk =
      | { type: 'reasoning' | 'text-delta'; textDelta: string }
      | { type: 'finish'; finishReason: any; usage: any; delta: any; chunk: any }
  impact: |
    The step markers (`// 1.` at lines 63 and 501, `// 2.` at 533, `// 3.` at 548, `// 5.` at 638, with no 4) narrate a generation process rather than describing the code.
    `OpenAIStreamChunk` is exported but used nowhere outside this file (grep). Its `finish` variant types every field as `any`, even though `Usage` and the OpenAI chunk types are already imported in this file.
  remedy: Remove the numbered narration. Make the type module-private, and type `usage` as `Usage` and `chunk` / `delta` with the OpenAI SDK chunk types.
  confidence: high
  overlap_hints: [craft.readability, api-contract.type-boundary]

## Files examined
examined: [src/renderer/src/middleware/convertLinksMiddleware.ts, src/renderer/src/middleware/extractReasoningMiddleware.ts, src/renderer/src/providers/AiProvider/BaseProvider.ts, src/renderer/src/providers/AiProvider/OpenAIProvider.ts, src/renderer/src/utils/getPotentialIndex.ts, src/renderer/src/utils/stream.ts]
not_examined: []
