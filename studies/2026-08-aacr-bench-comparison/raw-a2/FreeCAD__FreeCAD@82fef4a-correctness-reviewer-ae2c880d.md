<!-- FreeCAD__FreeCAD@82fef4a correctness-reviewer; verbatim final answer -->
One Nitpick finding. I found no correctness problems in the changed behaviour.

- severity: Nitpick
  category: correctness.side-effect
  file: src/Base/Parameter.cpp
  line: 1879
  title: The parser is now destroyed after the resolver and error handler it points to (the reverse of the old order)
  evidence: |
    auto parser = std::make_unique<XercesDOMParser>();
    auto entityBlocker = std::make_unique<NoOpEntityResolver>();
    ...
    parser->setEntityResolver(entityBlocker.get());
    auto errReporter = std::make_unique<DOMTreeErrorReporter>();
    parser->setErrorHandler(errReporter.get());
  impact: C++ destroys locals in reverse order of declaration. So on every return and throw path, `errReporter` and `entityBlocker` are destroyed first and `~XercesDOMParser` runs last, while it still holds pointers to both. The old code deleted `parser` first and `errReporter` after it. From what I know of Xerces, its destructor frees the scanner, grammar resolver and document without calling the handler or the resolver, so this should not crash today. I could not confirm that from local Xerces source, because searches outside the repo were blocked. If a future Xerces version calls either one during teardown, the parser would use freed memory.
  remedy: Declare `entityBlocker` and `errReporter` before `parser`, so the parser is destroyed first. Or call `parser.reset()` before the others go out of scope.
  confidence: medium
  overlap_hints: [craft]

Other points I checked and did not report:
- **Entity resolver:** `NoOpEntityResolver` does not change behaviour. `setDisableDefaultEntityResolution(true)` was already set, and a resolver that returns null in that mode acts the same as having no resolver. Its comment "Block all external entity resolution" gives it credit for what the existing flag already does. That is misleading but not a bug.
- **`std::endl` to `"\n"`:** `std::cerr` is unit-buffered, so output and flushing do not change.
- **Callers:** return values stay 0 on error and 1 on success, and the throws after `adoptDocument` are unchanged, so the `!= 1` checks keep working.
- **Leaks fixed:** the move to `unique_ptr` stops a leak of the parser and error reporter on the three `XMLBaseException` throw paths.
- **Build:** `<memory>` is included on both the precompiled-header and the non-precompiled paths. No other `NoOpEntityResolver` exists in `src/`, so there is no ODR clash.

## Files examined
examined: [src/Base/Parameter.cpp, src/Base/PreCompiled.h]
not_examined: []
