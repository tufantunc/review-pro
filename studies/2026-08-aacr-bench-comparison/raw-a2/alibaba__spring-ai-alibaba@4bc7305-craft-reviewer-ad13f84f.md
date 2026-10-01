<!-- alibaba__spring-ai-alibaba@4bc7305 craft-reviewer; verbatim final answer -->
## Craft findings

- severity: Medium
  category: craft.spaghetti
  file: spring-ai-alibaba-jmanus/src/main/java/com/alibaba/cloud/ai/example/manus/tool/browser/actions/InputTextAction.java
  line: 62
  title: Text input is now three nested try/catch blocks that drop errors, with step comments that describe the wrong steps
  evidence: |
    // 3. 尝试 fill
    try {
        elementLocator.fill(""); // 先清空
        com.microsoft.playwright.Locator.PressSequentiallyOptions options = new com.microsoft.playwright.Locator.PressSequentiallyOptions()
            .setDelay(100);
        elementLocator.pressSequentially(text, options);
    }
    catch (Exception e) {
        // 4. fill 失败，尝试 pressSequentially
        try {
            elementLocator.fill(""); // 再清空一次
            elementLocator.fill(text); // 直接填充
        }
        catch (Exception e2) {
            // 5. 还不行，直接用 JS 赋值并触发 input 事件
            try {
                elementLocator.evaluate("(el, value) => { ... }", text);
            }
            catch (Exception e3) {
                return new ToolExecuteResult("输入失败: " + e3.getMessage());
            }
        }
    }
  impact: |
    The fallback order is buried in nesting depth. The comments are numbered "3/4/5" with no 1 or 2, and they contradict the code: step 3 says "try fill" but runs pressSequentially, and step 4 says "try pressSequentially" but runs fill. Exceptions `e` and `e2` are dropped without logging. When step 3 throws partway through, the input has already received some characters before the next step clears it. To add, reorder or debug a strategy, you have to change the nesting. The same diff leaves the file with unused imports (`java.util.Random`, `ElementHandle`, `WaitForSelectorState`). It also spells out `com.microsoft.playwright.Locator.PressSequentiallyOptions` in full even though `Locator` is now imported.
  remedy: |
    Replace the pyramid with an ordered list of strategies, e.g. `List<Consumer<Locator>> strategies = List.of(l -> l.pressSequentially(text, new Locator.PressSequentiallyOptions().setDelay(100)), l -> l.fill(text), l -> l.evaluate(JS_SET_VALUE, text))`. Then use one loop: `fill("")`, try the strategy, return success on the first one that works, and log each failure. Write the error result from the last failure. Delete the wrong numbered comments and the dead imports, and use the imported `Locator.PressSequentiallyOptions`.
  confidence: high
  overlap_hints: [correctness.error-path, ai-antipatterns.over-engineering]

- severity: Medium
  category: craft.abstraction
  file: spring-ai-alibaba-jmanus/src/main/java/com/alibaba/cloud/ai/example/manus/tool/browser/actions/MoveToAndClickAction.java
  line: 54
  title: Debug overlay logic is pasted inline into a click action as concatenated JS, a second copy beside GetElementPositionByNameAction
  evidence: |
    boolean isDebug = getBrowserUseTool().getManusProperties().getBrowserDebug();
    ...
    String markerId = "__move_click_marker__";
    if (isDebug) {
        page.evaluate("(args) => {\n" + "  const [x, y, id] = args;\n"
                + "  let dot = document.getElementById(id);\n" + "  if (!dot) {\n"
                + "    dot = document.createElement('div');\n" + "    dot.id = id;\n"
                ...
                + "    document.body.appendChild(dot);\n" + "  }\n" + "}", new Object[] { x, y, markerId });
    }
    ...
    if (isDebug) {
        page.evaluate("(id) => { const dot = document.getElementById(id); if (dot) dot.remove(); }",
                new Object[] { markerId });
    }
  impact: |
    About 13 lines of the click action are now a debug overlay. It is split into two `if (isDebug)` blocks around the real work, so the business flow (scroll, move, click, detect a new tab) is hard to see. The JS is built by joining strings with `"\n"`, which is unreadable and fragile to edit. The repo already targets Java 17, and the sibling GetElementPositionByNameAction.java:140 builds its overlay JS with a text block. Each action now has its own debug-marker approach. The sibling's lookup of the same debug flag (GetElementPositionByNameAction.java:87) is never used to gate its overlay. The overlay is removed right after a synchronous click, so it is barely visible, which adds weight for little payoff.
  remedy: |
    Move the overlay into the base class as one helper, e.g. `protected void withDebugMarker(Page page, int x, int y, Runnable action)` (or `highlightPoint`) on BrowserAction. Have it read `getManusProperties().getBrowserDebug()` once, inject the marker using a text-block script constant, run the action, and remove the marker in a `finally`. MoveToAndClickAction then becomes `withDebugMarker(page, x, y, () -> { page.mouse().move(x, y); page.mouse().click(x, y); })`. GetElementPositionByNameAction can use the same helper and debug gate.
  evidence_refs: [spring-ai-alibaba-jmanus/src/main/java/com/alibaba/cloud/ai/example/manus/tool/browser/actions/GetElementPositionByNameAction.java:87, spring-ai-alibaba-jmanus/src/main/java/com/alibaba/cloud/ai/example/manus/tool/browser/actions/GetElementPositionByNameAction.java:140, spring-ai-alibaba-jmanus/src/main/java/com/alibaba/cloud/ai/example/manus/tool/browser/actions/BrowserAction.java:29]
  confidence: high
  overlap_hints: [dry.duplication]

- severity: Medium
  category: craft.code-judo
  file: spring-ai-alibaba-jmanus/src/main/java/com/alibaba/cloud/ai/example/manus/dynamic/agent/entity/DynamicAgentEntity.java
  line: 47
  title: Whitespace sentinel `" "` added for a deprecated field in the same change that already made its column nullable
  evidence: |
    -	@Column(nullable = false, length = 40000)
    +	@Column(length = 40000)
     	@Deprecated
    -	private String systemPrompt;
    +	private String systemPrompt = " ";
    --- AgentServiceImpl.java:200
    -			entity.setSystemPrompt(null);
    +			entity.setSystemPrompt(" ");
  impact: |
    The change applies two fixes for one problem (a NOT NULL constraint on a deprecated column). Dropping `nullable = false` is enough on its own. The magic `" "` then spreads "no value" as a fake value to two places. It is the field default and the reset value in `mergePrompts`. It also leaks out through `toAgentConfig` (AgentServiceImpl.java:157 `config.setSystemPrompt(entity.getSystemPrompt())`), so API consumers see a single space instead of absent. It also makes the existing guard at AgentServiceImpl.java:190 (`getSystemPrompt() != null || !...trim().isEmpty()`) always true for every entity. With the sentinel, "deprecated and empty" cannot be told apart from "has content", so the merge-and-warn branch runs on every load. The real invariant, a deprecated field that is never meaningfully set, is hidden behind a value that looks set.
  remedy: |
    Delete the sentinel. Keep the nullable column, initialize nothing, and go back to `setSystemPrompt(null)`. Rewrite the guard as `if (StringUtils.hasText(entity.getSystemPrompt()))`, which already exists in Spring and is used in this module (e.g. SerpApiService.java:70). The bigger move is to retire the field from the API path: stop copying it into AgentConfig at line 157. Then the deprecated column is only read once for migration in `mergePrompts`.
  evidence_refs: [spring-ai-alibaba-jmanus/src/main/java/com/alibaba/cloud/ai/example/manus/dynamic/agent/service/AgentServiceImpl.java:200, spring-ai-alibaba-jmanus/src/main/java/com/alibaba/cloud/ai/example/manus/dynamic/agent/service/AgentServiceImpl.java:190, spring-ai-alibaba-jmanus/src/main/java/com/alibaba/cloud/ai/example/manus/dynamic/agent/service/AgentServiceImpl.java:157, spring-ai-alibaba-jmanus/src/main/java/com/alibaba/cloud/ai/example/manus/tool/searchAPI/serpapi/SerpApiService.java:70]
  confidence: high
  overlap_hints: [correctness.logic, db.constraint, api-contract.schema-drift]

- severity: Low
  category: craft.layer-leak
  file: spring-ai-alibaba-jmanus/src/main/java/com/alibaba/cloud/ai/example/manus/tool/browser/actions/NavigateAction.java
  line: 41
  title: URL normalization is done inline in one action instead of at the request boundary
  evidence: |
    // 自动补全 URL 前缀
    if (!url.startsWith("http://") && !url.startsWith("https://")) {
        url = "https://" + url;
    }
  impact: |
    Input normalization for `BrowserRequestVO.url` lives inside one action, and it reassigns the parameter local. NewTabAction also takes a URL and does not get the same treatment, so the two URL-taking actions behave differently for the same input. The check is also scheme-blind: `about:blank`, `file://`, `data:` and `chrome://` URLs get rewritten to `https://about:blank` and similar.
  remedy: |
    Put one `normalizeUrl(String)` helper on BrowserAction, or apply it once in the request/VO layer. Have it check `URI.create(url).getScheme() == null` instead of matching only http/https prefixes. Call it from both NavigateAction and NewTabAction.
  confidence: medium
  overlap_hints: [correctness.logic, dry.duplication]

## Files examined
examined: [spring-ai-alibaba-jmanus/pom.xml, spring-ai-alibaba-jmanus/src/main/java/com/alibaba/cloud/ai/example/manus/dynamic/agent/entity/DynamicAgentEntity.java, spring-ai-alibaba-jmanus/src/main/java/com/alibaba/cloud/ai/example/manus/dynamic/agent/service/AgentServiceImpl.java, spring-ai-alibaba-jmanus/src/main/java/com/alibaba/cloud/ai/example/manus/tool/browser/actions/InputTextAction.java, spring-ai-alibaba-jmanus/src/main/java/com/alibaba/cloud/ai/example/manus/tool/browser/actions/MoveToAndClickAction.java, spring-ai-alibaba-jmanus/src/main/java/com/alibaba/cloud/ai/example/manus/tool/browser/actions/NavigateAction.java]
not_examined: []
