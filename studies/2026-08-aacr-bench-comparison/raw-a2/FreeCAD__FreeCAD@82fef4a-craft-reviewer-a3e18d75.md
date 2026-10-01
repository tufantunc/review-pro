<!-- FreeCAD__FreeCAD@82fef4a craft-reviewer; verbatim final answer -->
I found two craft issues in this change. Neither one breaks anything, but both add code that isn't needed.

- severity: Medium
  category: craft.code-judo
  file: src/Base/Parameter.cpp
  line: 1863
  title: NoOpEntityResolver probably does nothing that setDisableDefaultEntityResolution(true) doesn't already do; delete the class and both includes
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
        auto entityBlocker = std::make_unique<NoOpEntityResolver>();
        ...
        parser->setDisableDefaultEntityResolution(true);
        parser->setEntityResolver(entityBlocker.get());
  evidence_refs: [src/Base/Parameter.cpp:37, src/Base/Parameter.cpp:1880, src/Base/Parameter.cpp:1886-1887, src/Base/PreCompiled.h:107, src/Base/Parameter.cpp:2105]
  impact: |
    The parser already has setDisableDefaultEntityResolution(true), at line 1886 before this change. As I understand Xerces-C, that flag means: "if the entity resolver returns NULL, do not resolve the entity yourself." When no resolver is set, XercesDOMParser::resolveEntity already returns NULL. So a resolver that always returns nullptr adds nothing. I did not check this against the Xerces source; it is not vendored in the repo and I did not search the filesystem for it. Keeping the class costs a new type, an include in two files (Parameter.cpp:37 and PreCompiled.h:107), a heap-allocated object whose lifetime has to outlast the parse, and one setter call. It also implies that line 1886 is not enough, which may mislead the next reader. And it splits the two parser setups: CheckDocument (line 2105) relies on the flag alone, while LoadDocument now uses both the flag and the resolver. A maintainer is left wondering which one is correct.
  remedy: |
    First confirm the Xerces behaviour described above against the Xerces-C source. If it holds, delete NoOpEntityResolver, the `entityBlocker` local, the `setEntityResolver` call, and the EntityResolver.hpp include in both Parameter.cpp and PreCompiled.h. Then add a one-line comment next to `setDisableDefaultEntityResolution(true)` saying it is the guard against external entities. If the team still wants a resolver for defense in depth, pick one hardening policy and apply it to both parser setups, for example with a small file-local `configureSecureParser(XercesDOMParser&)` used by LoadDocument and CheckDocument. In that case, also move the class into the "private classes declaration" block at lines 75-158 and wrap it in an anonymous namespace. Leaving it partway through the file with external linkage breaks the file's own layout.
  confidence: medium
  overlap_hints: [security.xxe, correctness.side-effect]

- severity: Low
  category: craft.abstraction
  file: src/Base/Parameter.cpp
  line: 1879
  title: make_unique heap allocations where plain stack objects would do, unlike CheckDocument
  evidence: |
    auto parser = std::make_unique<XercesDOMParser>();
    auto entityBlocker = std::make_unique<NoOpEntityResolver>();
    ...
    auto errReporter = std::make_unique<DOMTreeErrorReporter>();
    parser->setErrorHandler(errReporter.get());
  evidence_refs: [src/Base/Parameter.cpp:2091, src/Base/Parameter.cpp:2107-2108]
  impact: |
    Switching from raw new/delete to unique_ptr is a real improvement. But none of these objects leaves the function, and nothing needs to be polymorphic or have a nullable owner. The heap allocation and `.get()` calls just add indirection. The same file already does the simpler thing: CheckDocument uses `XercesDOMParser parser;` and `DOMTreeErrorReporter errHandler; parser.setErrorHandler(&errHandler);`. The result is two different styles for the same setup in one file.
  remedy: |
    Use stack locals, as CheckDocument does: `XercesDOMParser parser; DOMTreeErrorReporter errReporter; parser.setErrorHandler(&errReporter);`. Declare the handler objects before the parser so the parser is destroyed first and never holds a dangling handler pointer. With `->` replaced by `.`, the function no longer uses smart pointers at all.
  confidence: high
  overlap_hints: []

## Files examined
examined: [src/Base/Parameter.cpp, src/Base/PreCompiled.h]
not_examined: []
