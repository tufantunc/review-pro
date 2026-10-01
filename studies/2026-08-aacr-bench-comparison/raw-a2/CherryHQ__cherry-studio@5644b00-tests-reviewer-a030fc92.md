<!-- CherryHQ__cherry-studio@5644b00 tests-reviewer; verbatim final answer -->
## Tests findings

- severity: High
  category: tests.coverage
  file: src/renderer/src/middleware/extractReasoningMiddleware.ts
  line: 80
  title: Streaming tag splitter across chunk boundaries has no tests
  evidence: |
    while (true) {
      const nextTag = isReasoning ? closingTag : openingTag
      const startIndex = getPotentialStartIndex(buffer, nextTag)
      if (startIndex == null) {
        publish(buffer)
        buffer = ''
        break
      }
      publish(buffer.slice(0, startIndex))
      const foundFullMatch = startIndex + nextTag.length <= buffer.length
      if (foundFullMatch) {
        buffer = buffer.slice(startIndex + nextTag.length)
        isReasoning = !isReasoning
        afterSwitch = true
      } else {
        buffer = buffer.slice(startIndex)
        break
      }
    }
  impact: |
    This stateful loop now decides which `<think>` text each OpenAI-compatible model sends to THINKING_DELTA and which to TEXT_DELTA. No test covers any of these branches:
    - a tag split across chunks (`"<th"` then `"ink>..."`)
    - the opening and closing tags arriving in one chunk
    - the separator prefix after a switch (`afterSwitch`, `isFirstReasoning`/`isFirstText`)
    - `startWithReasoning: true`
    - non-`text-delta` chunks passing through unchanged
    - a stream that ends with a partial-tag prefix still held in `buffer` (for example, text ending in `"<"`)
    There is no `flush()` handler, so that last case silently drops the trailing text, and no test would catch it.
  remedy: |
    Add `src/renderer/src/middleware/__tests__/extractReasoningMiddleware.test.ts`. Feed a `ReadableStream` built from an array of `{type:'text-delta', textDelta}` chunks and collect the output. Assert the exact emitted `{type, textDelta}` sequence for these cases:
    - `['<think>a', 'b</think>c']` → reasoning `a`, reasoning `b`, text `c`
    - `['<th', 'ink>x</th', 'ink>y']` → reasoning `x`, text `y`
    - `['a<think>b</think>c<think>d</think>e']` → checks the `\n` separator prefixes on the second reasoning and text segments
    - `startWithReasoning: true` with `['r</think>t']`
    - a `{type:'finish'}` chunk passes through unchanged
    - `['hello <']` → the output must end with `'hello <'` (this currently fails, see overlap)
    Also cover `wrapGenerate`: no match, multiple matches joined by the separator, and `text == null`.
  confidence: high
  overlap_hints: [correctness.logic]

- severity: High
  category: tests.coverage
  file: src/renderer/src/providers/AiProvider/OpenAIProvider.ts
  line: 548
  title: Rewritten OpenAI streaming dispatch (reasoning, text, finish, BLOCK_COMPLETE) is untested
  evidence: |
    case 'text-delta': {
      ...
      if (time_thinking_start > 0 && time_first_content_millsec === 0) {
        ...
        onChunk({ type: ChunkType.THINKING_COMPLETE, ...
    ...
    case 'finish': {
      ...
      await processToolUses(content, idx)
      onChunk({ type: ChunkType.BLOCK_COMPLETE, ...
  impact: |
    The change moves `processToolUses` and BLOCK_COMPLETE out of the post-loop position and into the `finish` case. A stream that ends without a `finish_reason`, or that is paused through `CHAT_COMPLETION_PAUSED`, now never emits BLOCK_COMPLETE and never runs tool use. Before this change both ran after the loop.
    The change also removes the old per-provider link converters: OpenRouter, Zhipu and Hunyuan, plus the `enableWebSearch` gating. Every chunk now goes through `convertLinks`, and the `delta.content`/`reasoning_content` mapping and THINKING_COMPLETE ordering were rewritten.
    No test exercises `processStream` (no OpenAIProvider test exists under `src/renderer`), so all of these behavior changes ship unverified.
  remedy: |
    Add an OpenAIProvider streaming test. Mock `window.keyv`, build an async iterable of `ChatCompletionChunk`-shaped objects, and capture the `onChunk` calls. Assert the ordered ChunkType sequence in these cases:
    - reasoning_content deltas, then content deltas, then a `finish_reason: 'stop'` chunk with usage → THINKING_DELTA..., THINKING_COMPLETE (once, with the joined thinking text), TEXT_DELTA..., TEXT_COMPLETE, BLOCK_COMPLETE with `usage`
    - an inline `<think>` content stream → reasoning is routed through the middleware
    - a stream with no `finish_reason` → BLOCK_COMPLETE is still expected
    - the pause flag set mid-stream
  confidence: high
  overlap_hints: [correctness.logic, correctness.breakage]

- severity: Medium
  category: tests.coverage
  file: src/renderer/src/middleware/convertLinksMiddleware.ts
  line: 20
  title: convertLinksMiddleware has no test, including state carrying over between streams
  evidence: |
    if (chunk.type === 'text-delta') {
      controller.enqueue({
        ...chunk,
        // @ts-expect-error: textDelta 只在 text-delta chunk 上
        textDelta: convertLinks(chunk.textDelta)
      })
  impact: |
    `convertLinks` keeps module-level state (`linkCounter`, `buffer`, `urlToCounterMap` in `src/renderer/src/utils/linkConverter.ts:2-6`). It only resets that state when `resetCounter=true`, and the middleware never passes that flag. The old call site passed `isFirstChunk` for exactly this reason.
    So link numbering and buffered partial text carry over from one completion to the next. A partial link left buffered at stream end is also never flushed. The existing tests in `linkConverter.test.ts` call `convertLinks` directly and cannot catch either problem.
  remedy: |
    Add `src/renderer/src/middleware/__tests__/convertLinksMiddleware.test.ts` with these cases:
    - one stream with `[example.com](https://a)` → assert the converted text, and that `reasoning` and `finish` chunks pass through unchanged
    - run two separate streams in sequence → assert the second stream's first link is numbered `[1]`
    - a stream ending in `'see [exa'` → assert the trailing text reaches the output
  confidence: high
  overlap_hints: [correctness.logic]

- severity: Medium
  category: tests.coverage
  file: src/renderer/src/utils/getPotentialIndex.ts
  line: 7
  title: getPotentialStartIndex has no unit tests for its suffix/prefix branches
  evidence: |
    if (searchedText.length === 0) {
      return null
    }
    const directIndex = text.indexOf(searchedText)
    if (directIndex !== -1) {
      return directIndex
    }
    for (let i = text.length - 1; i >= 0; i--) {
      const suffix = text.substring(i)
      if (searchedText.startsWith(suffix)) {
        return i
  impact: The reasoning splitter relies on this function to decide whether to hold back a partial tag. Nothing pins down the empty-search, direct-hit, partial-suffix and no-match branches, so a change here would mis-split reasoning without any test failing.
  remedy: |
    Add `src/renderer/src/utils/__tests__/getPotentialIndex.test.ts` with these cases:
    - `('abc', '')` → `null`
    - `('a<think>b', '<think>')` → `1`
    - `('hello <thi', '<think>')` → `6`
    - `('hello', '<think>')` → `null`
    - `('<', '<think>')` → `0`
    - `('x<think', '<think>')` → `1`
  confidence: high
  overlap_hints: []

- severity: Low
  category: tests.coverage
  file: src/renderer/src/utils/stream.ts
  line: 14
  title: readableStreamAsyncIterable and asyncGeneratorToReadableStream adapters are untested
  evidence: |
    export function asyncGeneratorToReadableStream<T>(gen: AsyncGenerator<T>): ReadableStream<T> {
      return new ReadableStream<T>({
        async pull(controller) {
          const { value, done } = await gen.next()
  impact: These adapters bridge the OpenAI SDK stream into the middleware chain. No test checks round-trip ordering or that the stream ends cleanly. Error propagation (a generator throw should reach the consumer) and early `break` releasing the reader (the iterator has no `return()`, so the lock stays held) are also unchecked.
  remedy: |
    Add `src/renderer/src/utils/__tests__/stream.test.ts` with these cases:
    - round-trip `[1, 2, 3]` through `asyncGeneratorToReadableStream` then `readableStreamAsyncIterable` → assert `[1, 2, 3]`
    - a generator that throws → assert the `for await` rejects with the same error
    - after a `break` mid-iteration → assert `stream.locked` (this documents the missing `return()`)
  confidence: medium
  overlap_hints: [correctness.error-path]

## Files examined
examined: [src/renderer/src/middleware/convertLinksMiddleware.ts, src/renderer/src/middleware/extractReasoningMiddleware.ts, src/renderer/src/providers/AiProvider/BaseProvider.ts, src/renderer/src/providers/AiProvider/OpenAIProvider.ts, src/renderer/src/utils/getPotentialIndex.ts, src/renderer/src/utils/stream.ts]
not_examined: []

Note: I read `BaseProvider.ts` and `OpenAIProvider.ts` through their diff hunks only, not the full files. The other four files I read in full. I also read `/Users/tufantunc/Desktop/Projects/Personal/aacr-bench/evaluation/work/CherryHQ__cherry-studio@5644b00/src/renderer/src/utils/linkConverter.ts` (lines 1-6 and 115-135), the test index of `/Users/tufantunc/Desktop/Projects/Personal/aacr-bench/evaluation/work/CherryHQ__cherry-studio@5644b00/src/renderer/src/utils/__tests__/linkConverter.test.ts`, and `vitest.config` (jsdom, global test includes) to back up the findings above.
