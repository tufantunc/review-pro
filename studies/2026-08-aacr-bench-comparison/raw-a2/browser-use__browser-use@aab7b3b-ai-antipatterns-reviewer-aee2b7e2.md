<!-- browser-use__browser-use@aab7b3b ai-antipatterns-reviewer; verbatim final answer -->
I found 5 issues in this change, all at Medium severity or lower. I couldn't check anything about patchright itself: it isn't installed here, there's no lockfile in the repo and web access was denied. Everything below is verified against the repo only.

- severity: Medium
  category: ai-antipatterns.needless-dep
  file: pyproject.toml
  line: 19
  title: patchright added as a runtime dependency but playwright kept; the library no longer imports playwright
  evidence: |
        "patchright>=1.51.0",
        "playwright>=1.51.0",
  impact: Searching `browser_use/` for `from|import playwright` finds nothing. Every runtime import is now `patchright.async_api`, including `browser_use/browser/context.py:17-22`, `browser.py:16-17`, `controller/service.py:11`, `controller/registry/views.py:3`, `dom/service.py:10` and `dolphin_service.py:6`. Only tests and examples still import playwright: `tests/test_browser.py:6` (`playwright._impl._api_structures.ProxySettings`), `tests/test_action_filters.py:4` and `examples/custom-functions/action_filters.py:23`. So every install pulls in two copies of the same driver stack. The documented install step (`README.md:33` `playwright install chromium`, `docs/quickstart.mdx:38` `uv run playwright install`) still uses the playwright CLI, which provisions browsers for the copy the library no longer uses. There is no lockfile, so nobody can see what the new package brings in transitively.
  remedy: Move the last 3 playwright imports to patchright, or keep playwright only as a dev/test extra. Then drop `playwright` from the runtime `dependencies`. Update README and quickstart to use patchright's own browser-install command.
  confidence: high
  evidence_refs: [tests/test_browser.py:6, tests/test_action_filters.py:4, examples/custom-functions/action_filters.py:23, README.md:33, docs/quickstart.mdx:38]
  overlap_hints: [correctness.devex, craft.boundary]

- severity: Medium
  category: ai-antipatterns.ignored-convention
  file: browser_use/browser/browser.py
  line: 283
  title: `channel='chrome'` is hard-coded for every browser_class, ignoring the existing firefox/webkit switch
  evidence: |
    		browser_class = getattr(playwright, self.config.browser_class)
    		args = {
    			'chromium': list(chrome_args),
    			'firefox': [ ... ],
    			'webkit': [ ... ],
    		}
    		browser = await browser_class.launch(
    			headless=self.config.headless,
    			channel='chrome',
  impact: The code around this call still picks the browser by `BrowserConfig.browser_class: Literal['chromium', 'firefox', 'webkit']` (browser.py:91) and builds separate args for each. The new line passes a Chrome-only channel no matter which one is chosen. A Chrome channel means nothing to firefox or webkit. For chromium, it silently swaps the bundled browser for a system Google Chrome install, which the docs never mention. If patchright only supports Chromium, the firefox/webkit branches and Literal values are dead code. I couldn't confirm that last point: no local package, network denied.
  remedy: Pass `channel='chrome'` only when `browser_class == 'chromium'`, ideally through a config field such as `BrowserConfig.channel`. If patchright really is Chromium-only, remove the firefox/webkit options instead of keeping dead branches. Document the Google Chrome requirement.
  confidence: medium
  overlap_hints: [correctness.broken-functionality, craft.boundary]

- severity: Medium
  category: ai-antipatterns.ignored-convention
  file: browser_use/agent/service.py
  line: 261
  title: Agent overwrites the browser's context config to sync disable_security, which belongs in the config model
  evidence: |
    		self.browser = browser or Browser()
    		self.browser.config.new_context_config.disable_security = self.browser.config.disable_security
  impact: Both config models are pydantic models with validators enabled (`BrowserConfig.model_config` sets `validate_assignment=True`, browser.py:79-86). The usual place to derive one field from another is a validator on `BrowserConfig`. Instead, the sync is done as a side effect in `Agent.__init__`. As a result:
    - An injected Browser's config is changed in place.
    - A user's explicit `BrowserContextConfig(disable_security=True)` is quietly reset to `BrowserConfig.disable_security`, which defaults to False.
    - Contexts made through `Browser.new_context()` (browser.py:125-127) never get the sync, so the behaviour depends on which entry point you use.
  remedy: Remove the line. Add a `model_validator(mode='after')` on `BrowserConfig` that copies `disable_security` into `new_context_config` only when the user didn't set it there, or have `BrowserContext` read `self.browser.config.disable_security` directly.
  confidence: high
  evidence_refs: [browser_use/browser/browser.py:79, browser_use/browser/browser.py:125, browser_use/browser/context.py:144]
  overlap_hints: [correctness.side-effect, craft.boundary]

- severity: Low
  category: ai-antipatterns.over-engineering
  file: browser_use/browser/context.py
  line: 423
  title: Conditional dict-splat replaces two plain boolean kwargs and does exactly the same thing
  evidence: |
    				**({'bypass_csp': True, 'ignore_https_errors': True} if self.config.disable_security else {}),
  impact: The old code `bypass_csp=self.config.disable_security, ignore_https_errors=self.config.disable_security` passed False when security was enabled, and False is the default for both options. The splat changes nothing in behaviour, contrary to the commit's "fix CSP" claim. It also mixes two ways of passing arguments (the `**kwargs` dict built above plus an inline splat) in one call.
  remedy: Go back to `bypass_csp=self.config.disable_security, ignore_https_errors=self.config.disable_security`. If the conditional `viewport`/`user_agent` handling needs a kwargs dict, put these two in the same dict.
  confidence: high
  overlap_hints: [craft.readability]

- severity: Low
  category: ai-antipatterns.ignored-convention
  file: browser_use/browser/context.py
  line: 446
  title: Stale "anti-detection" comment, and the playwright logger silencing was not carried over
  evidence: |
    		# Expose anti-detection scripts
    		await context.add_init_script(
    			"""
    			// Permissions
    			const originalQuery = window.navigator.permissions.query;
  impact: The webdriver, languages, plugins, chrome.runtime and attachShadow overrides were removed, leaving one permissions shim under a comment that still says "anti-detection scripts". In the same vein, `browser_use/logging_config.py:118` still silences only the `'playwright'` logger, and that file wasn't touched. If the renamed fork logs under its own package name, it will no longer be silenced. I couldn't confirm the fork's logger name.
  remedy: Update or remove the comment to match the one remaining shim, or drop the shim if patchright already handles it. Add `'patchright'` to the silenced loggers in `logging_config.py`.
  confidence: medium
  evidence_refs: [browser_use/logging_config.py:118]
  overlap_hints: [craft.readability]

## Files examined
examined: [browser_use/agent/service.py, browser_use/browser/browser.py, browser_use/browser/context.py, browser_use/browser/dolphin_service.py, browser_use/controller/registry/views.py, browser_use/controller/service.py, browser_use/dom/service.py, docs/customize/agent-settings.mdx, pyproject.toml, tests/test_attach_chrome.py, tests/test_full_screen.py]
not_examined: []
