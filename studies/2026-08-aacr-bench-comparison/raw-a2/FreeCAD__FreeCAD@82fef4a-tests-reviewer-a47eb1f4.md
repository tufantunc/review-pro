<!-- FreeCAD__FreeCAD@82fef4a tests-reviewer; verbatim final answer -->
- severity: Medium
  category: tests.coverage
  file: src/Base/Parameter.cpp
  line: 1863
  title: No test checks that the new NoOpEntityResolver blocks external entities
  evidence: |
    class NoOpEntityResolver: public XERCES_CPP_NAMESPACE_QUALIFIER EntityResolver
    {
    public:
        InputSource* resolveEntity(const XMLCh* const, const XMLCh* const) override
        {
            return nullptr;  // Block all external entity resolution
        }
    };
    ...
        parser->setEntityResolver(entityBlocker.get());
  impact: This change is an XXE hardening fix, but no test asserts it. `tests/src/Base/Parameter.cpp` has 24 `TEST_F` cases, and none contains a DOCTYPE, an ENTITY declaration or a `MemBufInputSource`. `src/Mod/Test/BaseTests.py` has no entity case either. If the resolver or `setDisableDefaultEntityResolution(true)` is removed or reordered later, all tests still pass. A resolver that returns `nullptr` tells Xerces to fall back to its default resolution. Nothing checks whether that fallback is really off in practice, which is the property the fix exists to guarantee.
  remedy: Add a `TEST_F(ParameterTest, TestExternalEntityNotResolved)`. Write a secret file (for example `<temp>.secret` containing `LEAK`). Write a config file whose DOCTYPE declares `<!ENTITY xxe SYSTEM "file://<secret path>">` and whose `FCText` value under the Root `FCParamGroup` is `&xxe;`. Then call `getConfig()->LoadDocument(fn.c_str())`. Either assert the return value is 0, or, if it loads, assert that `GetGroup(...)->GetASCII("Key")` is not `"LEAK"`. The fixture's `getFileName()`/`TearDown` temp-file pattern (`tests/src/Base/Parameter.cpp:45-60`, used in `TestSaveRestoreRef` at line 338) already supports this. You could also pass an in-memory `MemBufInputSource` to the public `LoadDocument(const InputSource&)` overload (`src/Base/Parameter.h:572`).
  evidence_refs: [tests/src/Base/Parameter.cpp:45, tests/src/Base/Parameter.cpp:338, src/Base/Parameter.h:572]
  confidence: high
  overlap_hints: [security.injection, correctness.logic]

- severity: Low
  category: tests.coverage
  file: src/Base/Parameter.cpp
  line: 1913
  title: The rewritten parse-error path (return 0, unique_ptr cleanup) has no test
  evidence: |
        if (errorsOccurred) {
            return 0;
        }
  impact: The change moves this error path from manual `delete` to RAII cleanup. The existing tests (`TestSaveRestoreRef`, `TestSaveRestoreNoRef`) only reach `LoadDocument` through `importFrom` with valid XML they wrote themselves, so they cover the success path only. If malformed input starts throwing, crashing, or leaving a half-set `_pDocument` instead of returning 0, no test catches it. `importFrom` at `src/Base/Parameter.cpp:289` relies on that return value.
  remedy: Add a test that writes non-well-formed XML (for example `<FCParameters><FCParamGroup Name="Root">`, left unclosed) to `getFileName()` and asserts `EXPECT_EQ(getConfig()->LoadDocument(fn.c_str()), 0)`. Optionally add a case for a well-formed document with no Root `FCParamGroup` that asserts `EXPECT_THROW(..., Base::XMLBaseException)`.
  evidence_refs: [tests/src/Base/Parameter.cpp:331, src/Base/Parameter.cpp:289]
  confidence: high
  overlap_hints: [correctness.error-path]

## Files examined
examined: [src/Base/Parameter.cpp, src/Base/PreCompiled.h]
not_examined: []
