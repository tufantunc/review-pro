<!-- browser-use__browser-use@aab7b3b correctness-reviewer; verbatim final answer -->
I found five correctness issues in this change. The most serious is that every browser launch is now hard-coded to Google Chrome.

- severity: High
  category: correctness.logic
  file: browser_use/browser/browser.py
  line: 283
  title: Every built-in launch now passes `channel='chrome'`, so Firefox/WebKit no longer work and Google Chrome must be installed
  evidence: |
    browser_class = getattr(playwright, self.config.browser_class)
    ...
    browser = await browser_class.launch(
    	headless=self.config.headless,
    	channel='chrome',
    	args=args[self.config.browser_class],
  evidence_refs: [browser_use/browser/browser.py:91, README.md:33, docs/quickstart.mdx:38]
  impact: |
    1. **Firefox and WebKit break.** `browser_class` still accepts `'firefox'` and `'webkit'` (browser.py:91), and the `args` dict still has entries for both. But `firefox.launch(channel='chrome')` and `webkit.launch(channel='chrome')` either reject the channel or look up the Chrome executable and try to run it as Firefox/WebKit. Either way those configs fail to launch.
    2. **The default chromium path now needs Google Chrome.** Without a system Chrome install, launch fails with "Chromium distribution 'chrome' is not found". The README (`playwright install chromium`) and quickstart (`uv run playwright install`) only install Playwright's bundled Chromium. So following the documented setup, `Agent(...)` with default `Browser()` fails on first use. Linux/Docker hosts are affected too (the code has `CHROME_DOCKER_ARGS` for them), since Chrome is usually not installed there.
  remedy: Pass `channel='chrome'` only when `browser_class == 'chromium'`, ideally behind a config option. Either fall back to bundled Chromium when Chrome is missing, or update README/quickstart to say `patchright install chrome`.
  confidence: high
  overlap_hints: [api-contract, correctness.devex]

- severity: Medium
  category: correctness.side-effect
  file: browser_use/agent/service.py
  line: 261
  title: Agent overwrites the user's `new_context_config.disable_security` with `BrowserConfig.disable_security` by mutating the injected Browser's config
  evidence: |
    self.browser = browser or Browser()
    self.browser.config.new_context_config.disable_security = self.browser.config.disable_security
  impact: |
    - If a user sets `BrowserConfig(new_context_config=BrowserContextConfig(disable_security=True))` and leaves the browser-level flag at its default `False`, creating an `Agent` silently resets the context flag to `False`. CSP bypass and HTTPS-error ignoring are then lost.
    - It writes into the caller's injected `Browser` object. Any `BrowserContextConfig` instance shared by the user is changed for all later consumers, including `Browser.new_context()` calls that never go through Agent.
    - The two flags only line up on the Agent path. `BrowserContext(browser, config)` built directly, or `browser.new_context()`, never get this sync, so the same config behaves differently depending on how the context was created.
  remedy: Don't mutate the injected config. When building the default context, derive the effective value without writing back, e.g. `ctx_cfg = self.browser.config.new_context_config.model_copy(update={'disable_security': ctx.disable_security or browser.disable_security})`. Or do the sync once in `BrowserConfig` via a validator.
  confidence: high
  overlap_hints: [api-contract]

- severity: Medium
  category: correctness.logic
  file: browser_use/browser/context.py
  line: 413
  title: Headed mode lost `no_viewport=True` and now falls back to Playwright's default 1280x720 viewport
  evidence: |
    kwargs = {}
    if self.browser.config.headless:
    	kwargs['viewport'] = self.config.browser_window_size
    	kwargs['no_viewport'] = False
    ...
    context = await browser.new_context(
    	**kwargs,
  evidence_refs: [browser_use/browser/browser.py:258, browser_use/browser/context.py:147]
  impact: |
    - Before, every new context used `no_viewport=True`, so in headed mode the page matched the real window. That window is launched with `--window-size` set to the screen resolution (browser.py:258).
    - Now headed mode passes neither `viewport` nor `no_viewport`, so Playwright emulates a fixed 1280x720 viewport inside a full-screen window.
    - Results: screenshots and the visible area shrink, viewport-based element filtering (`viewport_expansion`) and scroll math use 720px, and `record_video_size` (`browser_window_size`, 1280x1100) no longer matches the viewport.
    - The `BrowserContextConfig.no_viewport` field (context.py:147) is still ignored, so users have no way to opt back in.
  remedy: In headed mode pass `no_viewport=True` (and honour `self.config.no_viewport` when the user sets it). Use `viewport=browser_window_size` only for headless.
  confidence: high
  overlap_hints: []

- severity: Medium
  category: correctness.side-effect
  file: browser_use/browser/context.py
  line: 447
  title: Removing the init script that forced `attachShadow` to `mode: 'open'` hides closed shadow-DOM content from DOM extraction
  evidence: |
    await context.add_init_script(
    	"""
    	// Permissions
    	const originalQuery = window.navigator.permissions.query;
    	...
    	"""
    )
  evidence_refs: [browser_use/dom/buildDomTree.js:977]
  impact: buildDomTree.js:977 walks shadow trees only through `if (node.shadowRoot) { ... node.shadowRoot.childNodes ... }`, and `element.shadowRoot` is `null` for closed shadow roots. Before, the init script forced every shadow root open, so its content was extracted. Now elements inside closed shadow roots (common in web-component sites and some login/consent widgets) are missing from the DOM tree the LLM sees, and the agent can't target them. patchright's own closed-shadow locator support doesn't help here, because extraction runs in page JS.
  remedy: Keep the shadow-root override, or switch shadow traversal to a mechanism that can reach closed roots (e.g. CDP `DOM.describeNode` with `pierce: true`). If dropping the override for stealth is deliberate, document the lost coverage.
  confidence: medium
  overlap_hints: []

- severity: Low
  category: correctness.logic
  file: browser_use/browser/context.py
  line: 154
  title: Default `user_agent` changed to None, so headless sessions now send the browser's native "HeadlessChrome" user agent
  evidence: |
    user_agent: str | None = None
    ...
    if self.config.user_agent is not None:
    	kwargs['user_agent'] = self.config.user_agent
  evidence_refs: [browser_use/browser/context.py:93]
  impact: Before, every context sent a fixed desktop Chrome user agent. Now headless contexts send Chrome's default user agent, which contains `HeadlessChrome`, so headless users are flagged by user-agent checks more easily, which works against this anti-detection change. The docstring at context.py:93 still documents the old default.
  remedy: In headless mode, when the user gives no user agent, set one from the real Chrome version with `HeadlessChrome` replaced by `Chrome`. Update the docstring either way.
  confidence: medium
  overlap_hints: [craft]

## Files examined
examined: [browser_use/agent/service.py, browser_use/browser/browser.py, browser_use/browser/context.py, browser_use/browser/dolphin_service.py, browser_use/controller/registry/views.py, browser_use/controller/service.py, browser_use/dom/service.py, docs/customize/agent-settings.mdx, pyproject.toml, tests/test_attach_chrome.py, tests/test_full_screen.py]
not_examined: []
