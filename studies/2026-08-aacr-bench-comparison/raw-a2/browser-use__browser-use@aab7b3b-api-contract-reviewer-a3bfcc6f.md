<!-- browser-use__browser-use@aab7b3b api-contract-reviewer; verbatim final answer -->
I found 5 API-contract issues. Two are High: the default launch now requires a system Google Chrome, and `browser_class='firefox'`/`'webkit'` can no longer launch. I couldn't check patchright's or Playwright's source locally (running Python needed approval and the repo has no lockfile), so the claims about launch errors rely on how Playwright is known to behave.

- severity: High
  category: api-contract.breaking
  file: browser_use/browser/browser.py
  line: 283
  title: The default `Browser()` launch now needs Google Chrome installed, but the install docs still say `playwright install chromium`
  evidence: |
    browser = await browser_class.launch(
        headless=self.config.headless,
        channel='chrome',
        args=args[self.config.browser_class],
  impact: Every built-in launch path (`Browser()` with no cdp/wss/binary path) now asks for the branded Chrome stable channel instead of the bundled Chromium. README.md:33 (`playwright install chromium`) and docs/quickstart.mdx:38 (`uv run playwright install`) are unchanged. Both install only the bundled Chromium, and only for playwright's driver, not patchright's. A user who follows the docs on a machine without system Chrome (most CI and Docker setups) gets a launch failure on the very first `Agent(...).run()`. `BrowserConfig` gets no new field or option, and nothing in the change mentions this.
  remedy: Make the channel configurable, e.g. `BrowserConfig.channel: str | None = 'chromium'`, and only pass `channel` when it is set. Alternatively, fall back to the bundled Chromium when Chrome is missing. Update README.md and docs/quickstart.mdx to `patchright install chrome` (or `chromium`).
  confidence: high
  evidence_refs: [README.md:33, docs/quickstart.mdx:38]
  overlap_hints: [correctness.breakage]

- severity: High
  category: api-contract.breaking
  file: browser_use/browser/browser.py
  line: 91
  title: The `browser_class` Literal still accepts `firefox`/`webkit`, but every launch now passes `channel='chrome'`
  evidence: |
    browser_class: Literal['chromium', 'firefox', 'webkit'] = 'chromium'
    ...
    browser_class = getattr(playwright, self.config.browser_class)
    ...
        'firefox': [ ... '-no-remote', ... ],
        'webkit': [ ... '--no-startup-window', ... ],
    ...
    browser = await browser_class.launch(headless=..., channel='chrome', ...)
  impact: The public config still validates `BrowserConfig(browser_class='firefox')` and `'webkit'`, and still builds per-engine args for them (browser.py:267-278). But `channel='chrome'` is now passed to `firefox.launch` and `webkit.launch` too. In Playwright this is rejected as an unsupported channel for that engine, and patchright only targets Chromium anyway. So two values the type advertises can no longer work, with no deprecation or validation error. The user only finds out at runtime.
  remedy: Either narrow the Literal to `'chromium'` (or add a validator that rejects firefox/webkit with a clear message), or pass `channel` only when `browser_class == 'chromium'`.
  confidence: medium
  overlap_hints: [correctness.breakage]

- severity: Medium
  category: api-contract.breaking
  file: browser_use/agent/service.py
  line: 261
  title: `Agent.__init__` silently overwrites the public `BrowserContextConfig.disable_security` field
  evidence: |
    self.browser = browser or Browser()
    self.browser.config.new_context_config.disable_security = self.browser.config.disable_security
  impact: `BrowserContextConfig.disable_security` (context.py:144) is a documented public field. If a user sets `BrowserConfig(new_context_config=BrowserContextConfig(disable_security=True))` and leaves `BrowserConfig.disable_security` at its default `False`, their setting is now reset to `False` with no warning. As a result, `bypass_csp` and `ignore_https_errors` are no longer applied (context.py:423). The reverse case flips too. The write also mutates the caller's own `BrowserConfig` object. It runs even when a `browser_context` is injected, and it changes what later `browser.new_context()` calls get, since they now default to `self.config.new_context_config` (browser.py:127). In-repo examples set both fields the same way (examples/use-cases/web_voyager_agent.py:29-31), so none of them show the break, but external callers who set only the context-level field lose their setting.
  remedy: Only copy the value when the context-level field was not set explicitly (check `'disable_security' not in new_context_config.model_fields_set`), or do the merge in `BrowserConfig` with a validator. Don't mutate the config from `Agent`.
  confidence: high
  overlap_hints: [correctness.side-effect, security.config]

- severity: Medium
  category: api-contract.types
  file: browser_use/controller/registry/views.py
  line: 3
  title: Public `Page`/`ElementHandle`/`BrowserContext` types switched from playwright to patchright classes with no compatibility note, while playwright stays installed
  evidence: |
    from patchright.async_api import Page
    ...
    page_filter: Callable[[Page], bool] | None = None
  impact: The public action API, `registry.action(page_filter=...)` and `RegisteredAction.page_filter`, plus what `BrowserContext.get_current_page()` returns, now use `patchright.async_api` classes. These are different classes from `playwright.async_api`. Code in the repo still annotates against playwright: examples/custom-functions/action_filters.py:23 and tests/test_action_filters.py:4 (`from playwright.async_api import Page`). At runtime pydantic doesn't check the `Callable` argument type, so these still run. But type checkers will flag a mismatch, and any user `isinstance(page, playwright.async_api.Page)` check is now `False`. User code that wraps browser_use page calls in `except playwright.async_api.TimeoutError`/`Error` won't catch patchright's own exception classes either. Because pyproject.toml still lists `playwright>=1.51.0`, mixed imports keep resolving and the mismatch never surfaces at import time. The change does update docs/customize/agent-settings.mdx, so the switch is intentional, but only that doc says so.
  remedy: Re-export the page/error types from a browser_use module (e.g. `browser_use.browser.types`) so users don't hard-code either package. Update the example and test imports. Document the switch, especially exception classes, in the release notes.
  confidence: medium
  evidence_refs: [examples/custom-functions/action_filters.py:23, tests/test_action_filters.py:4, pyproject.toml:19-20]
  overlap_hints: [ai-antipatterns.needless-dependency]

- severity: Low
  category: api-contract.schema
  file: browser_use/browser/context.py
  line: 154
  title: `user_agent` default changed from a fixed string to `None`, but the docstring and docs still show the old default
  evidence: |
    user_agent: str | None = None
    # docstring, context.py:93:
    user_agent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.102 Safari/537.36'
  impact: The field type widened to nullable and the default changed, so contexts now send the browser's own user agent instead of the fixed Chrome/85 string. The class docstring (context.py:93) and docs/customize/browser-settings.mdx:122 still present the old Chrome/85 string as the default. Users who relied on the documented default get a different user agent, and the docs no longer match the model.
  remedy: Update the docstring and browser-settings.mdx to say `None` (use the browser's native user agent), and mention the default change in the changelog.
  confidence: high
  evidence_refs: [browser_use/browser/context.py:93, docs/customize/browser-settings.mdx:122]
  overlap_hints: []

Two of the orchestrator's leads turned out not to be problems:
- **`validation_alias` change:** with `populate_by_name=True`, both the field name and the old aliases still validate, so nothing breaks.
- **`Browser.new_context` default:** it now passes `new_context_config`. Before, it passed a `BrowserConfig` where a `BrowserContextConfig` was expected, so this is a fix, not a break.

## Files examined
examined: [browser_use/agent/service.py, browser_use/browser/browser.py, browser_use/browser/context.py, browser_use/browser/dolphin_service.py, browser_use/controller/registry/views.py, browser_use/controller/service.py, browser_use/dom/service.py, docs/customize/agent-settings.mdx, pyproject.toml, tests/test_attach_chrome.py, tests/test_full_screen.py]
not_examined: []
