<!-- CherryHQ__cherry-studio@5644b00 performance-reviewer; verbatim final answer -->
- severity: High
  category: performance.complexity
  file: src/renderer/src/middleware/convertLinksMiddleware.ts
  line: 20
  title: convertLinks now runs on every text token of every OpenAI-compatible stream, and its hold-back buffer grows without bound, so cost per token grows with response length
  evidence: |
    if (chunk.type === 'text-delta') {
      controller.enqueue({
        ...chunk,
        // @ts-expect-error: textDelta 只在 text-delta chunk 上
        textDelta: convertLinks(chunk.textDelta)
      })
  evidence_refs:
    - src/renderer/src/providers/AiProvider/OpenAIProvider.ts:544
    - src/renderer/src/utils/linkConverter.ts:4
    - src/renderer/src/utils/linkConverter.ts:164
    - src/renderer/src/utils/linkConverter.ts:191
  impact: |
    Before this change, OpenAIProvider called convertLinks only when `assistant.enableWebSearch && delta?.annotations` (merge-base line 597). Now `convertLinksMiddleware` is wired in without any condition (OpenAIProvider.ts:544), so every text-delta of every chat goes through it.

    convertLinks keeps a module-level `buffer` (linkConverter.ts:4). On each call it scans backward from the end of that buffer. When it reaches a `[` (or `([`) that is not a complete `[text](url)`, it holds everything from that point (linkConverter.ts:164-191). Normal output often has such a bracket: `arr[0]`, `[1, 2, 3]`, `- [ ]` checkboxes, footnote-style `[1]`. After one appears, every later token is appended to the held buffer. Each call then does an O(L) scan back to that bracket, plus `buffer.substring(i)` and a regex `exec` whose `[^\]]+` can walk the whole remainder.

    Total work is O(n^2) in response length. Assumed scale: a 50 KB code answer at about 4 chars per token is roughly 12k calls, with buffers averaging about 25 KB, so on the order of 300M character operations. All of it runs synchronously on the renderer thread inside the stream transform, which can cause visible jank late in long answers.

    Nothing resets or flushes the buffer either. `resetCounter` is never passed (the old code passed `isFirstChunk`), so the held text stays in memory across later streams.
  remedy: |
    Gate the middleware as the old code did: only apply it when web search is enabled and the provider emits link annotations. Pass a reset at stream start. Better still, make the converter per-stream state created inside `wrapStream` instead of module globals, and make it give up holding back once the buffer passes a small cap (for example 512 chars since the last `[`) or a newline. Add a `flush` handler to the TransformStream so it emits whatever is still buffered when the stream ends.
  confidence: high
  overlap_hints: [correctness.logic, frontend.state]

- severity: Low
  category: performance.memory
  file: src/renderer/src/utils/linkConverter.ts
  line: 6
  title: urlToCounterMap and buffer are now app-lifetime state that is never reset, because the middleware never passes resetCounter
  evidence: |
    // in convertLinksMiddleware.ts:20 — no reset argument
    textDelta: convertLinks(chunk.textDelta)
    // linkConverter.ts:6
    let urlToCounterMap: Map<string, number> = new Map()
  evidence_refs:
    - src/renderer/src/middleware/convertLinksMiddleware.ts:20
  impact: Every URL seen in any OpenAI-compatible response for the whole session stays in `urlToCounterMap`, and `linkCounter` keeps increasing. Memory grows slowly, linear in distinct URLs per session. Each entry is small (a few KB per hundred links), so the memory cost is minor. The larger effect is state carried between conversations, which correctness owns.
  remedy: Create the converter state per stream inside `wrapStream` (a closure or class instance), or call `convertLinks(text, true)` on the first text-delta of each stream.
  confidence: high
  overlap_hints: [correctness.logic]

- severity: Low
  category: performance.memory
  file: src/renderer/src/utils/stream.ts
  line: 1
  title: The stream adapters never cancel or return the upstream, so an error in the consumer leaves the OpenAI HTTP stream open
  evidence: |
    export function readableStreamAsyncIterable<T>(stream: ReadableStream<T>): AsyncIterable<T> {
      const reader = stream.getReader()
      return {
        [Symbol.asyncIterator](): AsyncIterator<T> {
          return {
            async next(): Promise<IteratorResult<T>> {
              return reader.read() as Promise<IteratorResult<T>>
            }
          }
        }
      }
    }
    ...
    return new ReadableStream<T>({
      async pull(controller) { ... }
    })   // no cancel() -> gen.return() never called
  evidence_refs:
    - src/renderer/src/providers/AiProvider/OpenAIProvider.ts:549
    - src/renderer/src/providers/BaseProvider.ts:197
  impact: Before, `for await (const chunk of stream)` ran directly over the OpenAI SDK stream, so an exception in the loop body called `iterator.return()`, which closes the SDK response. Now the consumer loops over `readableStreamAsyncIterable` (OpenAIProvider.ts:549). If `onChunk` or `processToolUses` throws, the iterator has no `return()` to release the reader lock or cancel the stream, and `asyncGeneratorToReadableStream` has no `cancel()` to call `gen.return()`. The generator stays suspended at a `yield` while still holding the SDK iterator and the response body. `cleanup()` (BaseProvider.ts:197) only removes the abort handler; it does not abort, so the connection and its buffered chunks stay alive until the server closes it or GC runs. This is one leaked connection per failed stream, so the impact is low but real when errors repeat.
  remedy: Add `return()` to the iterator that calls `reader.cancel()` and `reader.releaseLock()`, and add `cancel(reason) { return gen.return(undefined) }` to the ReadableStream source. Alternatively use the native `ReadableStream` async iteration, which handles both.
  confidence: medium
  overlap_hints: [correctness.error-path, backend.error-handling]

## Files examined
examined: [src/renderer/src/middleware/convertLinksMiddleware.ts, src/renderer/src/middleware/extractReasoningMiddleware.ts, src/renderer/src/providers/AiProvider/BaseProvider.ts, src/renderer/src/providers/AiProvider/OpenAIProvider.ts, src/renderer/src/utils/getPotentialIndex.ts, src/renderer/src/utils/stream.ts]
not_examined: []
