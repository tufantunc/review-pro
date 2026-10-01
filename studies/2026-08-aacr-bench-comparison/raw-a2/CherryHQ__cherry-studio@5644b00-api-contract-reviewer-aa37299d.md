<!-- CherryHQ__cherry-studio@5644b00 api-contract-reviewer; verbatim final answer -->
I found four contract problems in the OpenAI streaming rewrite. The most serious: link conversion now runs on every OpenAI-compatible response with no first-chunk reset and no end-of-stream flush. As a result, text can be lost from the final answer, leak into the next reply, and break tool calls.

- severity: High
  category: api-contract.breaking
  file: src/renderer/src/middleware/convertLinksMiddleware.ts
  line: 20
  title: convertLinks is called without its resetCounter argument, on every response, with nothing to flush its buffer
  evidence: |
    if (chunk.type === 'text-delta') {
      controller.enqueue({
        ...chunk,
        // @ts-expect-error: textDelta 只在 text-delta chunk 上
        textDelta: convertLinks(chunk.textDelta)
      })
  evidence_refs: [src/renderer/src/utils/linkConverter.ts:2, src/renderer/src/utils/linkConverter.ts:4, src/renderer/src/utils/linkConverter.ts:123, src/renderer/src/utils/linkConverter.ts:165-189, src/renderer/src/providers/AiProvider/OpenAIProvider.ts:544, src/renderer/src/services/StreamProcessingService.ts:58]
  impact: |
    `convertLinks(text, resetCounter = false, isZhipu = false)` keeps its buffer (`let buffer`), link counter and URL map at module level. Callers must pass `resetCounter=true` on the first chunk. The old code passed `isFirstChunk`, and only when `assistant.enableWebSearch` was on.
    The new middleware never resets and runs on every text delta of every OpenAI-compatible response. It has no `flush()` handler.
    `convertLinks` holds back everything from the last `[` that is not a complete `[x](url)` link. Common examples are `- [ ] item`, `arr[0]` and JSON arrays. That held-back tail:
    1. Never reaches TEXT_DELTA.
    2. Is missing from `content`, so TEXT_COMPLETE (`StreamProcessingService.ts:58` → `onTextComplete`) is missing it too.
    3. Is prepended to the first chunk of the next streamed response.
    4. Reaches `processToolUses(content, idx)`. A `<tool_use>` whose arguments contain `[1,2]` loses `...</arguments></tool_use>`, so the tool never runs.
    Link numbering also carries over between messages.
  remedy: Create converter state per stream. Reset it on the first text-delta (pass `true`), and add a `flush(controller)` that emits whatever is still buffered. Only apply link conversion when web search is on, as before.
  confidence: high
  overlap_hints: [correctness.logic, correctness.regression]

- severity: Medium
  category: api-contract.breaking
  file: src/renderer/src/providers/AiProvider/OpenAIProvider.ts
  line: 526
  title: BLOCK_COMPLETE is no longer guaranteed; it is only sent if a chunk arrives with a non-empty finish_reason
  evidence: |
    if (!isEmpty(finishReason)) {
      yield { type: 'finish', finishReason, usage: chunk.usage, delta, chunk }
      break
    }
    ...
    case 'finish': {
      ...
      await processToolUses(content, idx)
      onChunk({ type: ChunkType.BLOCK_COMPLETE, ...
  evidence_refs: [src/renderer/src/providers/AiProvider/OpenAIProvider.ts:515, src/renderer/src/providers/AiProvider/OpenAIProvider.ts:641, src/renderer/src/services/StreamProcessingService.ts:45, src/renderer/src/store/thunk/messageThunk.ts:602]
  impact: |
    At the merge base, `processToolUses` and the BLOCK_COMPLETE emit came after the `for await` loop, so they ran however the loop ended.
    Now both live only in the `'finish'` case. If the stream ends without a non-empty `finish_reason`, or the `CHAT_COMPLETION_PAUSED` break fires, there is no BLOCK_COMPLETE and no tool processing. Some OpenAI-compatible backends may end a stream that way.
    BLOCK_COMPLETE is the only trigger for `onComplete(SUCCESS, response)` (`StreamProcessingService.ts:45`). Without it, `messageThunk.ts:602` never sets the final message status, metrics or usage, and never saves them to the DB. The message stays in its streaming state.
    This depends on provider behaviour; the pause key is set only in commented-out code (`TopicsTab.tsx:99`).
  remedy: Move `processToolUses` and BLOCK_COMPLETE back after the consume loop, so they run however the stream ends. Keep the `'finish'` case for TEXT_COMPLETE, usage and web-search chunks only.
  confidence: medium
  overlap_hints: [correctness.error-path]

- severity: Medium
  category: api-contract.breaking
  file: src/renderer/src/providers/AiProvider/OpenAIProvider.ts
  line: 544
  title: Provider-specific citation conversion (Zhipu, Hunyuan, OpenRouter, OpenAI annotations) was dropped
  evidence: |
    -            } else if (isZhipuModel(assistant.model)) {
    -              delta.content = convertLinksToZhipu(delta.content || '', isFirstChunk)
    -            } else if (isHunyuanSearchModel(assistant.model)) {
    -              delta.content = convertLinksToHunyuan(
    +      const { stream: processedStream } = await convertLinksMiddleware<OpenAIStreamChunk>().wrapStream({
  evidence_refs: [src/renderer/src/utils/linkConverter.ts:25, src/renderer/src/utils/linkConverter.ts:60, src/renderer/src/utils/linkConverter.ts:269]
  impact: |
    With web search on, Zhipu `[ref_N]` markers, Hunyuan citations (which need `search_info.search_results`) and OpenRouter link formats are no longer rewritten into numbered citations. Their TEXT_DELTA and TEXT_COMPLETE text now differs from what the renderer showed before for those providers.
    The LLM_WEB_SEARCH_COMPLETE results are still emitted, but the inline citation markers no longer match them.
  remedy: Give the middleware a converter choice per provider/model and the search results (or send `chunk.search_info` through the stream). Keep the old dispatch, including the `enableWebSearch` gate.
  confidence: high
  overlap_hints: [correctness.regression, spec.missing]

- severity: Low
  category: api-contract.types
  file: src/renderer/src/providers/AiProvider/OpenAIProvider.ts
  line: 66
  title: The exported OpenAIStreamChunk uses `any` fields, and the middleware generics hide the textDelta access with @ts-expect-error
  evidence: |
    export type OpenAIStreamChunk =
      | { type: 'reasoning' | 'text-delta'; textDelta: string }
      | { type: 'finish'; finishReason: any; usage: any; delta: any; chunk: any }
    ...
    export function extractReasoningMiddleware<T extends { type: string } = { type: string; textDelta: string }>(
    ...
    // @ts-expect-error: textDelta 只在 text-delta/reasoning chunk 上
    buffer += chunk.textDelta
  evidence_refs: [src/renderer/src/providers/AiProvider/OpenAIProvider.ts:596, src/renderer/src/middleware/extractReasoningMiddleware.ts:62, src/renderer/src/middleware/extractReasoningMiddleware.ts:69, src/renderer/src/middleware/convertLinksMiddleware.ts:19]
  impact: |
    - `lastUsage = usage` puts an `any` into `Usage` without a check, and `rawChunk.citations` / `web_search` / `search_info` are unchecked reads.
    - The generic constraint does not require `textDelta`, so the compiler cannot catch a T that lacks it.
    - `extractReasoningMiddleware` enqueues `type: 'reasoning'` into any `T extends {type: string}`, even if T's union has no `'reasoning'` member. It works today only because the one caller's union happens to include it.
  remedy: Constrain the generic to `T extends { type: string; textDelta?: string }`, or take a fixed union that contains `'reasoning'`. Type the finish members as `OpenAI.Chat.Completions.ChatCompletionChunk['choices'][number]['finish_reason']`, `CompletionUsage` and so on.
  confidence: high
  overlap_hints: [craft.type-boundary]

On the questions you passed along:
- **`handleThinkingTags` removal:** safe. Nothing in `src` references it, and nothing extends `OpenAIProvider`.
- **Chunk order:** on the normal path it is the same as at the merge base. The changes are that BLOCK_COMPLETE is no longer guaranteed (finding 2), and that `<think>` content inside `delta.content` now arrives as THINKING_DELTA instead of TEXT_DELTA. That second change looks intentional, and I found no consumer it breaks.

I did not run the type check because `node_modules` is not installed, so whether the `@ts-expect-error` lines compile is unconfirmed.

## Files examined
examined: [src/renderer/src/middleware/convertLinksMiddleware.ts, src/renderer/src/middleware/extractReasoningMiddleware.ts, src/renderer/src/providers/AiProvider/BaseProvider.ts, src/renderer/src/providers/AiProvider/OpenAIProvider.ts, src/renderer/src/utils/getPotentialIndex.ts, src/renderer/src/utils/stream.ts]
not_examined: []
