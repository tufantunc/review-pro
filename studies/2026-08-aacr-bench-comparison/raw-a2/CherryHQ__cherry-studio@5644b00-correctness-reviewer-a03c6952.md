<!-- CherryHQ__cherry-studio@5644b00 correctness-reviewer; verbatim final answer -->
I found five correctness problems. The first two are blocking: any OpenAI-compatible stream that contains a stray `[` loses text, and the loss can carry over into the next reply. I couldn't run a repro script because writes outside the repo weren't permitted. The `convertLinks` results below come from tracing the source line by line.

- severity: Critical
  category: correctness.logic
  file: src/renderer/src/middleware/convertLinksMiddleware.ts
  line: 20
  title: convertLinks now runs on every OpenAI-compatible reply, never resets and never flushes, so it drops reply text and carries it into later replies
  evidence: |
    textDelta: convertLinks(chunk.textDelta)
    // linkConverter.ts
    let buffer = ''                                  // module-level
    export function convertLinks(text: string, resetCounter = false, isZhipu = false): string {
      if (resetCounter) { linkCounter = 1; buffer = ''; urlToCounterMap = new Map() }
      buffer += text
      ...
      } else if (buffer[i] === '[') {
        const match = /^\[([^\]]+)\]\(([^)]+)\)/.exec(substring)
        if (!match) { safePoint = i; break }
      ...
      buffer = buffer.substring(safePoint)
  evidence_refs: [src/renderer/src/utils/linkConverter.ts:4, src/renderer/src/utils/linkConverter.ts:123-128, src/renderer/src/utils/linkConverter.ts:178-192, src/renderer/src/providers/AiProvider/OpenAIProvider.ts:544-546, src/renderer/src/providers/AiProvider/OpenAIProvider.ts:571, src/renderer/src/providers/AiProvider/OpenAIProvider.ts:593, src/renderer/src/store/thunk/messageThunk.ts:375-383]
  impact: |
    - **Before:** `convertLinks` ran only when `assistant.enableWebSearch` was on. It was passed `isFirstChunk`, so its module-level buffer was cleared at the start of each reply.
    - **Now:** it runs on every text delta from OpenAIProvider (most providers), always with `resetCounter=false`. Nothing else in the app calls a reset.
    - **What gets held back:** any `[` that doesn't start a complete `[text](url)`, such as `x = [1, 2, 3]`, `arr[0]` or `- [ ]`, marks a cut point. Everything from the last such `[` to the end of the stream stays in the buffer.
    - **No flush:** the TransformStream has no `flush`, so that tail is never emitted. `content` and TEXT_COMPLETE are truncated, and `onTextComplete` saves the truncated text over the block.
    - **Carry-over:** the stale buffer is still there when the next reply starts (also when `processToolUses` recurses).
    - **Traced example:** reply 1 is "Use a list: x = [1, 2, 3]\nprint(x)\nDone." and shows only "Use a list: x = ". Reply 2 is "Hello, how can I help?" and shows nothing, because the scan still stops at the old `[` at index 0. The stale text only comes out, inside some later reply, when that reply has its own unmatched `[`.
  remedy: Gate link conversion on web search as before, and pick the converter per provider. Keep converter state per stream, either by resetting on the first chunk or making the converter a factory with its own state. Add a `flush()` to the TransformStream that emits whatever is left in the buffer.
  confidence: high
  overlap_hints: [correctness.side-effect, tests.coverage]

- severity: High
  category: correctness.side-effect
  file: src/renderer/src/middleware/convertLinksMiddleware.ts
  line: 17
  title: Ordinary markdown links and images in every reply are rewritten as citation superscripts, which breaks images
  evidence: |
    if (chunk.type === 'text-delta') {
      controller.enqueue({ ...chunk, textDelta: convertLinks(chunk.textDelta) })
    // linkConverter.ts:242-246
    if (isHost(linkText)) { result += `[<sup>${counter}</sup>](${url})` }
    else { result += `${linkText}[<sup>${counter}</sup>](${url})` }
  evidence_refs: [src/renderer/src/utils/linkConverter.ts:224-246]
  impact: |
    - This conversion is no longer limited to web-search replies; it now hits normal chat output.
    - `See [the docs](https://x)` becomes `See the docs[<sup>1</sup>](https://x)`.
    - `![logo](https://img.png)` becomes `!logo[<sup>1</sup>](https://img.png)`, so the markdown image no longer renders.
    - Link-like text inside code blocks is rewritten the same way.
  remedy: Apply the conversion only when web search is enabled, as the old code did.
  confidence: high
  overlap_hints: [correctness.logic]

- severity: Medium
  category: correctness.side-effect
  file: src/renderer/src/providers/AiProvider/OpenAIProvider.ts
  line: 544
  title: The provider-specific citation converters (Zhipu, Hunyuan, OpenRouter) are no longer called
  evidence: |
    const { stream: processedStream } = await convertLinksMiddleware<OpenAIStreamChunk>().wrapStream({
      doStream: async () => ({ stream: reasoningStream })
    })
    // removed: convertLinksToOpenRouter / convertLinksToZhipu / convertLinksToHunyuan(delta.content, chunk.search_info.search_results, isFirstChunk)
  evidence_refs: [src/renderer/src/utils/linkConverter.ts:25-110, src/renderer/src/utils/linkConverter.ts:269-318]
  impact: |
    - **Zhipu:** `[ref_N]` markers now show up raw.
    - **Hunyuan:** `[1](@ref)` goes through the generic converter and becomes `1[<sup>1</sup>](@ref)`. The real URL from `search_info.search_results` is never filled in.
    - **OpenRouter:** links whose text is not a host are now rewritten too; before, only host-style links were.
  remedy: Bring back the per-provider dispatch inside the middleware, passing the model/provider and the Hunyuan search results.
  confidence: high
  overlap_hints: [spec]

- severity: Medium
  category: correctness.error-path
  file: src/renderer/src/providers/AiProvider/OpenAIProvider.ts
  line: 639
  title: TEXT_COMPLETE, tool processing and BLOCK_COMPLETE now run only when a non-empty finish_reason arrives
  evidence: |
    case 'finish': {
      ...
      await processToolUses(content, idx)
      onChunk({ type: ChunkType.BLOCK_COMPLETE, ... })
  evidence_refs: [src/renderer/src/providers/AiProvider/OpenAIProvider.ts:513-531, src/renderer/src/services/StreamProcessingService.ts:45-47, src/renderer/src/store/thunk/messageThunk.ts:602-640, src/renderer/src/services/ApiService.ts:265-272]
  impact: |
    - **Before:** `processToolUses` and BLOCK_COMPLETE ran unconditionally after the `for await` loop.
    - **Now:** they run only inside the `'finish'` case. If a stream ends without a finish_reason, none of them run:
      - an OpenAI-compatible server or proxy that omits it;
      - a stream cut off cleanly;
      - the `CHAT_COMPLETION_PAUSED` break.
    - **Consequences:**
      - `onComplete` never fires and `fetchChatCompletion` has no fallback, so the message's final status, usage and metrics are never set. I couldn't confirm what the UI then shows.
      - Prompt-based MCP tool calls in the text are never run.
    - **Caveat:** I did not establish which providers omit finish_reason, hence medium confidence.
  remedy: After the consume loop, emit TEXT_COMPLETE (if not already sent), call `processToolUses` and emit BLOCK_COMPLETE whenever `finish` was not seen. Or move those steps after the loop as before, and keep only usage and web-search capture in the `'finish'` case.
  confidence: medium
  overlap_hints: [correctness.logic]

- severity: Low
  category: correctness.logic
  file: src/renderer/src/middleware/extractReasoningMiddleware.ts
  line: 56
  title: Reasoning transform has no flush, so a trailing partial tag prefix is dropped
  evidence: |
    new TransformStream<T, T>({
      transform: (chunk, controller) => { ...
          } else {
            buffer = buffer.slice(startIndex)
            break
  impact: |
    - `getPotentialStartIndex` returns the start of any suffix that could begin `<think>`, including a lone `<` or `<th`, and that suffix is held in the buffer.
    - Mid-stream this is harmless: the next delta releases it.
    - At the end of a stream, a reply ending in such a suffix (for example a code answer ending in `<`) loses those characters. `content` and TEXT_COMPLETE are truncated.
  remedy: Add `flush(controller)` that publishes any remaining `buffer` as the current type (reasoning or text-delta).
  confidence: high
  overlap_hints: [tests.coverage]

## Files examined
examined: [src/renderer/src/middleware/convertLinksMiddleware.ts, src/renderer/src/middleware/extractReasoningMiddleware.ts, src/renderer/src/providers/AiProvider/BaseProvider.ts, src/renderer/src/providers/AiProvider/OpenAIProvider.ts, src/renderer/src/utils/getPotentialIndex.ts, src/renderer/src/utils/stream.ts]
not_examined: []
