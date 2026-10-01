<!-- browser-use__browser-use@aab7b3b tests-reviewer; verbatim final answer -->
I found 5 test-quality issues. The change adds new branching to how browser contexts and browsers are launched, but adds no tests for it. The only test files it touches (`tests/test_attach_chrome.py`, `tests/test_full_screen.py`) change one import line each.

- severity: High
  category: tests.coverage
  file: browser_use/browser/context.py
  line: 413
  title: The new kwargs logic in `_create_context` has no test
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
  impact: This replaces the old fixed `no_viewport=True` / `user_agent=...` / `bypass_csp=disable_security` call with three independent branches. Nothing checks what `browser.new_context` actually receives. A regression would go unnoticed, for example a headful run getting a fixed viewport, a `user_agent=None` being forwarded, or `bypass_csp`/`ignore_https_errors` being dropped when `disable_security=True`. `tests/test_context.py` covers other `BrowserContext` methods but never `_create_context`.
  remedy: In `tests/test_context.py`, reuse the existing `Mock()` browser/config pattern (e.g. `test_is_url_allowed`, line 20). Pass a fake playwright browser whose `new_context` is an `AsyncMock` with `contexts=[]` and `add_init_script` stubbed. Parametrize over headless True/False, user_agent None/'UA', and disable_security True/False. For each case, assert on `new_context.call_args.kwargs`: `viewport`/`no_viewport` are present only when headless, `user_agent` only when not None, and `bypass_csp`/`ignore_https_errors` only when disable_security.
  confidence: high
  overlap_hints: [correctness.logic]

- severity: Medium
  category: tests.coverage
  file: browser_use/agent/service.py
  line: 261
  title: `Agent.__init__` now changes the browser's `new_context_config.disable_security`, with no test
  evidence: |
    self.browser = browser or Browser()
    self.browser.config.new_context_config.disable_security = self.browser.config.disable_security
  impact: This line now decides whether the CSP and HTTPS bypass is applied to contexts the Agent creates. It also runs when the caller injects a `browser`, overwriting a `new_context_config.disable_security` the caller set explicitly. No test covers it, so a broken sync, or an unwanted overwrite of a user's explicit value, would ship silently.
  remedy: Add a unit test that builds `Agent` with a mocked LLM and `Browser(BrowserConfig(disable_security=True))`, then asserts `agent.browser_context.config.disable_security is True`. Add the reverse case: `BrowserConfig(disable_security=False, new_context_config=BrowserContextConfig(disable_security=True))`. Assert whatever the intended precedence is, so the overwrite is a documented decision.
  confidence: high
  overlap_hints: [correctness.side-effect, api-contract]

- severity: Medium
  category: tests.coverage
  file: browser_use/browser/browser.py
  line: 127
  title: The `new_context()` default (no-argument) path changed, but only the explicit-config path is tested
  evidence: |
    return BrowserContext(config=config or self.config.new_context_config, browser=self)
  impact: The old code passed the whole `BrowserConfig` as the context config. That was a bug, and this change fixes it. But `tests/test_browser.py:226-237` (`test_new_context_creation`) only calls `new_context(custom_context_config)`. The fixed branch, used by `async with await browser.new_context()` in docs and in `tests/test_stress.py:36`, has no regression test.
  remedy: Add `context = await browser_obj.new_context()` with `assert context.config is browser_obj.config.new_context_config`. Also check that a field set on `BrowserConfig(new_context_config=BrowserContextConfig(locale='de-DE'))` shows up on `context.config`.
  confidence: high
  overlap_hints: [correctness.logic]

- severity: Medium
  category: tests.assertion
  file: browser_use/browser/browser.py
  line: 283
  title: The new `channel='chrome'` launch kwarg is not checked, and the existing launch mocks reject extra kwargs
  evidence: |
    browser = await browser_class.launch(
        headless=self.config.headless,
        channel='chrome',
        args=args[self.config.browser_class],
        proxy=self.config.proxy,
        handle_sigterm=False,
  evidence_refs: [tests/test_browser.py:24, tests/test_browser.py:196]
  impact: The mocks in `tests/test_browser.py` are declared as `async def launch(self, headless, args, proxy=None)`, so they cannot accept `channel`, `handle_sigterm` or `handle_sigint`. The `handle_*` incompatibility already existed before this change. The result is that `test_builtin_browser_launch` and `test_builtin_browser_disable_security_args` raise TypeError before reaching their assertions. Nothing verifies the new `channel='chrome'` value either. That matters because it is also passed when `browser_class` is 'firefox' or 'webkit', where a Chrome channel does not apply.
  remedy: Change the dummy `launch` to `async def launch(self, headless, args, proxy=None, **kwargs)` and assert `kwargs.get('channel') == 'chrome'` for chromium. Add a firefox `browser_class` case asserting the intended channel behaviour (probably no `channel`).
  confidence: high
  overlap_hints: [correctness.logic]

- severity: Low
  category: tests.coverage
  file: browser_use/browser/browser.py
  line: 92
  title: Moving the `browser_binary_path` alias from `alias=` to `validation_alias=` has no test
  evidence: |
    browser_binary_path: str | None = Field(
        default=None, validation_alias=AliasChoices('browser_instance_path', 'chrome_instance_path')
    )
  impact: The switch to `validation_alias` changes which keyword names the constructor accepts. The legacy `chrome_instance_path` / `browser_instance_path` names and the canonical `browser_binary_path` name should all keep working. The existing test (`tests/test_browser.py:153`) uses only `browser_binary_path=` and does not check the stored field, so any regression in the legacy aliases would go unseen.
  remedy: Add a small parametrized test: for each of `chrome_instance_path`, `browser_instance_path` and `browser_binary_path`, assert `BrowserConfig(**{name: '/x/chrome'}).browser_binary_path == '/x/chrome'`.
  confidence: medium
  overlap_hints: [api-contract]

Two smaller observations, not filed as findings:
- The init script no longer includes the `attachShadow` override that forced shadow roots open. That changes what DOM extraction can see, and no test in `browser_use/dom/tests` covers closed shadow roots. Whether removing it is a bug is a question for the correctness reviewer.
- `tests/test_attach_chrome.py` and `tests/test_full_screen.py` define `test_full_screen(start_fullscreen, maximize)` with arguments that are not fixtures, so pytest errors if it collects them. That predates this change, which only edited their imports.

## Files examined
examined: [browser_use/agent/service.py, browser_use/browser/browser.py, browser_use/browser/context.py, browser_use/browser/dolphin_service.py, browser_use/controller/registry/views.py, browser_use/controller/service.py, browser_use/dom/service.py, docs/customize/agent-settings.mdx, pyproject.toml, tests/test_attach_chrome.py, tests/test_full_screen.py]
not_examined: []
