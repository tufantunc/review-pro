<!-- browser-use__browser-use@aab7b3b security-reviewer; verbatim final answer -->
## Security findings: none

I checked every security-relevant change in the diff, and none of them opens a vulnerability.

- **`agent/service.py:261` copies the browser's `disable_security` onto the context config.** There are two cases.
  - **Browser flag is True, context flag is False:** The context now also gets `bypass_csp=True` and `ignore_https_errors=True`. Chrome is already started with `--ignore-certificate-errors`, `--ignore-ssl-errors` and `--disable-web-security` from `CHROME_DISABLE_SECURITY_ARGS` (`browser_use/browser/chrome.py:49-60`, applied at `browser.py:199` and `browser.py:252`). So the context flags add no new exposure. The user also turned this on themselves, and the setting is documented as dangerous at `browser.py:98`.
  - **Browser flag is False, context flag is True:** The context flag is now forced to False. That makes the browser more secure, not less. Silently overriding the user's setting is a correctness problem, not a security one.
- **`browser.py:127`, `Browser.new_context()`:** It used to pass the whole `BrowserConfig` in as the context config, so `disable_security` came from the browser-level setting. It now uses `new_context_config`, where the default is False. Security is the same or tighter.
- **`browser.py:283`, `channel='chrome'`:** This starts the Google Chrome installed on the machine. It uses `launch()`, not `launch_persistent_context`, so it gets a fresh temporary profile and never touches the user's real profile, cookies or saved logins. No boundary is crossed. It is also set even when `browser_class` is firefox or webkit, which is a correctness issue for another reviewer.
- **`context.py`, removed init scripts:** Removing the webdriver, languages and plugins spoofing and the override that forced shadow roots open only changes how detectable the bot is. No trust boundary is involved.
- **`context.py:154`, `user_agent` now defaults to None:** This has no security effect.
- **`pyproject.toml`, new `patchright>=1.51.0` dependency:** It has the same open-ended version floor as the existing `playwright>=1.51.0`. It is a maintained Playwright fork, and I don't know of any advisory against it. I found nothing to report.
- **Import swaps** in `dolphin_service.py`, `controller/registry/views.py`, `controller/service.py`, `dom/service.py`, the docs file and the two tests: these only change which package the same names come from. Nothing about security changes.

## Files examined
examined: [browser_use/agent/service.py, browser_use/browser/browser.py, browser_use/browser/context.py, browser_use/browser/dolphin_service.py, browser_use/controller/registry/views.py, browser_use/controller/service.py, browser_use/dom/service.py, docs/customize/agent-settings.mdx, pyproject.toml, tests/test_attach_chrome.py, tests/test_full_screen.py]
not_examined: []
