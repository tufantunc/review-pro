<!-- browser-use__browser-use@aab7b3b craft-reviewer; verbatim final answer -->
## Craft findings

- severity: Medium
  category: craft.layer-leak
  file: browser_use/agent/service.py
  line: 261
  title: Agent mutates the browser's nested config to keep two copies of `disable_security` in sync
  evidence: |
    		self.browser = browser or Browser()
    +		self.browser.config.new_context_config.disable_security = self.browser.config.disable_security
    		self.browser_context = browser_context or BrowserContext(
    			browser=self.browser, config=self.browser.config.new_context_config
    		)
  impact: The rule "the context's disable_security follows the browser's" now lives in the orchestration layer, not in the browser package that owns both configs. Contexts made any other way (`Browser.new_context()` at browser.py:125–127, a direct `BrowserContext(...)`, or a `browser_context` passed in) never get the sync. So whether CSP bypass applies depends on how the context was built. The line also writes over the config of a `Browser` the caller passed in, and overwrites any `disable_security` value the user set on `new_context_config`. `BrowserContextConfig.disable_security` (context.py:144) and `BrowserConfig.disable_security` (browser.py:98) are now two fields for one concept, joined by a side effect in an unrelated class.
  remedy: Delete line 261 and keep the rule inside the browser package. `_create_context` already reads browser-level settings (`self.browser.config.headless`, `self.browser.config.cdp_url`), so read `self.browser.config.disable_security or self.config.disable_security` there. Better still, drop the duplicated context field, or add a `model_validator` on `BrowserConfig` that propagates the value into `new_context_config` once, when the config is built. Either way, Agent no longer needs to know about the browser's config layout.
  confidence: high
  overlap_hints: [correctness.side-effect, api-contract.config]

- severity: Medium
  category: craft.boundary
  file: pyproject.toml
  line: 19
  title: Partial library swap with no single alias module; both `playwright` and `patchright` are now in the dependency list
  evidence: |
    +    "patchright>=1.51.0",
         "playwright>=1.51.0",
    # still on playwright after the change:
    # tests/test_browser.py:6: from playwright._impl._api_structures import ProxySettings
    # tests/test_action_filters.py:4: from playwright.async_api import Page
    # examples/custom-functions/action_filters.py:23: from playwright.async_api import Page
  evidence_refs: [browser_use/controller/registry/views.py:3, browser_use/browser/context.py:17, browser_use/browser/browser.py:16, tests/test_browser.py:6, tests/test_action_filters.py:4, examples/custom-functions/action_filters.py:23]
  impact: Which driver the project uses is hard-coded in 7 library modules, and some modules import the private path (`patchright._impl._errors`). That is why this migration had to touch every file, and why it stopped partway. The registry's public `Page` type (controller/registry/views.py:3), which user action-filter callbacks receive, is now patchright's. The shipped example and the test still annotate it with playwright's `Page`, so public types disagree with the documented usage. Keeping both packages means two driver installs, and it is unclear which one the code depends on.
  remedy: Add one internal alias module, for example `browser_use/browser/_driver.py`, that re-exports `async_playwright`, `Playwright`, `Browser`, `BrowserContext`, `Page`, `ElementHandle`, `FrameLocator`, `TimeoutError` and `ProxySettings` from the chosen backend. Import only from that module everywhere. Then finish the swap (tests, examples, `ProxySettings`) and drop `playwright` from `pyproject.toml`, or keep it on purpose as a documented fallback inside that one module.
  confidence: high
  overlap_hints: [dry.duplication, ai-antipatterns.needless-dependency, api-contract.type-boundary]

- severity: Medium
  category: craft.spaghetti
  file: browser_use/browser/browser.py
  line: 283
  title: Chromium-only `channel='chrome'` added to the launch call that every browser class shares
  evidence: |
    		browser_class = getattr(playwright, self.config.browser_class)
    		args = {
    			'chromium': list(chrome_args),
    			'firefox': [ ... ],
    			'webkit': [ ... ],
    		}

    		browser = await browser_class.launch(
    			headless=self.config.headless,
    +			channel='chrome',
    			args=args[self.config.browser_class],
  impact: The function already uses `args`, keyed by `browser_class`, to keep per-engine options apart. The new option skips that dispatch and forces a Chrome channel for firefox and webkit launches too. A per-engine concern now sits unconditionally in the shared path, and anyone reading the call has to know that `channel` only means something for chromium.
  remedy: Make the dispatch per-engine launch kwargs instead of per-engine args, for example `launch_opts = {'chromium': {'args': ..., 'channel': 'chrome'}, 'firefox': {'args': ...}, 'webkit': {'args': ...}}`, and call `browser_class.launch(headless=..., proxy=..., **launch_opts[self.config.browser_class], ...)`. If a channel should be configurable, make it a `BrowserConfig` field rather than a hard-coded literal.
  confidence: high
  overlap_hints: [correctness.logic]

- severity: Low
  category: craft.spaghetti
  file: browser_use/browser/context.py
  line: 413
  title: Two different idioms for optional kwargs in one `new_context` call; the init-script comment no longer matches the script
  evidence: |
    			kwargs = {}
    			if self.browser.config.headless:
    				kwargs['viewport'] = self.config.browser_window_size
    				kwargs['no_viewport'] = False
    			if self.config.user_agent is not None:
    				kwargs['user_agent'] = self.config.user_agent

    			context = await browser.new_context(
    				**kwargs,
    				java_script_enabled=True,
    				**({'bypass_csp': True, 'ignore_https_errors': True} if self.config.disable_security else {}),
    	...
    		# Expose anti-detection scripts
    		await context.add_init_script(
    			"""
    			// Permissions
  impact: A reader has to merge a pre-built dict, an inline conditional splat and literal kwargs to see what is actually passed. `no_viewport=False` is redundant once `viewport` is set. The "anti-detection scripts" comment now sits over a single permissions shim, which misleads anyone looking for where stealth behaviour is handled (it now comes from patchright).
  remedy: Build every conditional option in the one `kwargs` dict (put `bypass_csp`/`ignore_https_errors` in an `if self.config.disable_security:` block next to the others), remove `no_viewport=False`, and pass `**kwargs` once. Rename the comment to describe what the script does now (notification-permission shim), or move the shim to a named module-level constant.
  confidence: high
  overlap_hints: []

## Files examined
examined: [browser_use/agent/service.py, browser_use/browser/browser.py, browser_use/browser/context.py, browser_use/browser/dolphin_service.py, browser_use/controller/registry/views.py, browser_use/controller/service.py, browser_use/dom/service.py, docs/customize/agent-settings.mdx, pyproject.toml, tests/test_attach_chrome.py, tests/test_full_screen.py]
not_examined: []
