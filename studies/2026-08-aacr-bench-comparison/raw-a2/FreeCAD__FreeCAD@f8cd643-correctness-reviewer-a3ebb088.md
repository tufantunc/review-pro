<!-- FreeCAD__FreeCAD@f8cd643 correctness-reviewer; verbatim final answer -->
## Correctness findings

- severity: Low
  category: correctness.devex
  file: src/Mod/ReverseEngineering/Gui/Command.cpp
  line: 71
  title: The change adds the first Unicode "…" literals to FreeCAD C++ source, in a module that doesn't pass /utf-8 to MSVC
  evidence: |
    sMenuText = QT_TR_NOOP("Approximate B-Spline Curve…");
    ...
    sMenuText = QT_TR_NOOP("Poisson…");
    // App/AppReverseEngineering.cpp:1002
    Base::Console().log("Loading ReverseEngineering module… done\n");
  evidence_refs: [src/Mod/ReverseEngineering/Gui/Command.cpp:104, src/Mod/ReverseEngineering/Gui/Command.cpp:424, src/Mod/ReverseEngineering/Gui/Command.cpp:456, src/Mod/ReverseEngineering/Gui/Command.cpp:536, src/Mod/ReverseEngineering/Gui/Command.cpp:601, src/Mod/ReverseEngineering/App/AppReverseEngineering.cpp:1002, src/Mod/ReverseEngineering/Gui/AppReverseEngineeringGui.cpp:85, src/Mod/TechDraw/Gui/CMakeLists.txt:1-3, src/Gui/InputHintWidget.cpp:266]
  impact: |
    - `git grep -l "…" -- 'src/*.cpp' 'src/*.h' 'src/*.py' 'src/*.ui'` returns only these three ReverseEngineering files.
    - The files have no BOM (first bytes are `2f 2a 2a`). The only MSVC `/utf-8` flag in the build is in `src/Mod/TechDraw/Gui/CMakeLists.txt`, added by commit 974da86cb4 "fix: windows build need /utf-8".
    - On MSVC with a multibyte code page (for example CP936/GBK), the 3-byte sequence E2 80 A6 is decoded as one double-byte character plus a stray lead byte A6. That lead byte can swallow the next byte.
    - In the six `QT_TR_NOOP("...…")` menu strings the next byte is the closing `"`. That can cause a C2001 "newline in constant" error or a garbled `sMenuText`, which would no longer match the translation key.
    - In the two log lines the next byte is a space, so the log text gets mangled.
    - This is a known exposure, not a new class of problem: `src/Gui/InputHintWidget.cpp` already has 3-byte UTF-8 literals before a closing quote with no `/utf-8`. On CP1252 and on GCC/Clang the bytes pass through unchanged.
  remedy: Add `if(MSVC) add_compile_options(/utf-8) endif()` to the ReverseEngineering App and Gui CMakeLists, as TechDraw/Gui does. Otherwise keep ASCII "..." in the C++ literals until the build sets `/utf-8` globally.
  confidence: medium
  overlap_hints: [craft]

- severity: Nitpick
  category: correctness.devex
  file: src/Mod/ReverseEngineering/App/AppReverseEngineering.cpp
  line: 1002
  title: The module-load log line now differs from every other module's "... done" pattern
  evidence: |
    Base::Console().log("Loading ReverseEngineering module… done\n");
  evidence_refs: [src/Mod/ReverseEngineering/Gui/AppReverseEngineeringGui.cpp:85, src/App/FreeCADInit.py:284, src/Gui/FreeCADGuiInit.py:319]
  impact: |
    - 45 other C++ module inits log "module... done" with ASCII, as do the Python init scripts.
    - Grepping the FreeCAD log for "... done" to check module-load status will now miss ReverseEngineering (both App and Gui).
    - No in-repo tool parses these lines, so nothing breaks functionally. The log is internal and not user-facing UI, so the UI-string convention the commit cites doesn't need to apply here.
  remedy: Revert the two `Console().log` lines to ASCII "...". Keep "…" only in user-visible menu texts.
  confidence: high
  overlap_hints: [craft]

Other checks found nothing wrong:
- **Command names:** `sWhatsThis` and command names are unchanged. `Shortcuts.cfg` and the Workbench item lists key off `Reen_*` names, not text.
- **Translation contexts:** the `translate()` contexts are unchanged.
- **Submenu rename:** nothing in the repo looks up "Surface reconstruction". It was never in the lupdate block or `ReverseEngineering.ts`, so it was already untranslated.
- **Tests and scripts:** no tests or Python scripts reference the changed strings.

## Files examined
examined: [src/Mod/ReverseEngineering/App/AppReverseEngineering.cpp, src/Mod/ReverseEngineering/App/RegionGrowing.cpp, src/Mod/ReverseEngineering/Gui/AppReverseEngineeringGui.cpp, src/Mod/ReverseEngineering/Gui/Command.cpp, src/Mod/ReverseEngineering/Gui/FitBSplineCurve.ui, src/Mod/ReverseEngineering/Gui/FitBSplineSurface.cpp, src/Mod/ReverseEngineering/Gui/FitBSplineSurface.ui, src/Mod/ReverseEngineering/Gui/Segmentation.ui, src/Mod/ReverseEngineering/Gui/SegmentationManual.ui, src/Mod/ReverseEngineering/Gui/Workbench.cpp]
not_examined: []
