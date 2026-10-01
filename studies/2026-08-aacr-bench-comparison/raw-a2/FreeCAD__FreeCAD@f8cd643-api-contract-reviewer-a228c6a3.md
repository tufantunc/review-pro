<!-- FreeCAD__FreeCAD@f8cd643 api-contract-reviewer; verbatim final answer -->
I found one minor contract inconsistency. Nothing in the diff breaks a consumer I could locate.

- severity: Nitpick
  category: api-contract.schema
  file: src/Mod/ReverseEngineering/App/RegionGrowing.cpp
  line: 108
  title: Reworded RuntimeError now differs from five sibling throws for the same condition
  evidence: |
    throw Base::RuntimeError("Number of points does not match with number of normals");
    // unchanged siblings, src/Mod/ReverseEngineering/App/SurfaceTriangulation.cpp:137,260,374,566,676:
    throw Base::RuntimeError("Number of points doesn't match with number of normals");
  evidence_refs: [src/Mod/ReverseEngineering/App/SurfaceTriangulation.cpp:137, src/Mod/ReverseEngineering/App/SurfaceTriangulation.cpp:260, src/Mod/ReverseEngineering/App/SurfaceTriangulation.cpp:374, src/Mod/ReverseEngineering/App/SurfaceTriangulation.cpp:566, src/Mod/ReverseEngineering/App/SurfaceTriangulation.cpp:676, src/Mod/ReverseEngineering/App/AppReverseEngineering.cpp:147, src/Mod/ReverseEngineering/App/AppReverseEngineering.cpp:99]
  impact: The same error now has two wordings in the Python module `ReverseEngineering`. `regionGrowingSegmentation` (exposed at AppReverseEngineering.cpp:147) raises the new wording. `triangulate`, `poissonReconstruction` and the other SurfaceTriangulation paths (exposed from AppReverseEngineering.cpp:99) still raise the old one. No Python file in the repo matches on either string. An out-of-tree script that matched the old text on `regionGrowingSegmentation` would stop matching, and one handler can no longer catch the error by a single message. That works against the commit's own consistency goal.
  remedy: Either apply the same rewording to the five SurfaceTriangulation.cpp throws, or keep RegionGrowing.cpp on the old wording until all six are changed together.
  confidence: high
  overlap_hints: [correctness.consistency]

These other areas turned out not to be findings:
- **Menu lookup keys:** The submenu key changed from "Surface reconstruction" to "Surface Reconstruction" (Workbench.cpp:53). Nothing in `src` uses either string as a lookup key; its only occurrence is the `setCommand` itself. The keys other code depends on are unchanged: `&Windows` for `findItem`, the top-level `&Reverse Engineering` menu, and the "Reverse Engineering" toolbar name. Customized toolbars are stored in user config under that toolbar name.
- **Translations:** The submenu string was never marked for lupdate, so it has no entry in any `.ts` file. The `Workbench` context in ReverseEngineering.ts only contains "Reverse Engineering". Renaming it therefore orphans no translation. The other rewordings (sMenuText/sToolTipText, QMessageBox text, `.ui` strings) will orphan existing `.ts` entries until the next lupdate and translation sync. That is FreeCAD's normal string-update workflow, not a contract break.
- **Command identity:** No command class names or `sWhatsThis` values changed. The `Reen_*` IDs that Shortcuts.cfg:449-458 refers to still match.
- **Log strings:** The two `Base::Console().log` loading messages ("..." became "…") are not parsed by anything in the repo.

## Files examined
examined: [src/Mod/ReverseEngineering/App/AppReverseEngineering.cpp, src/Mod/ReverseEngineering/App/RegionGrowing.cpp, src/Mod/ReverseEngineering/Gui/AppReverseEngineeringGui.cpp, src/Mod/ReverseEngineering/Gui/Command.cpp, src/Mod/ReverseEngineering/Gui/FitBSplineCurve.ui, src/Mod/ReverseEngineering/Gui/FitBSplineSurface.cpp, src/Mod/ReverseEngineering/Gui/FitBSplineSurface.ui, src/Mod/ReverseEngineering/Gui/Segmentation.ui, src/Mod/ReverseEngineering/Gui/SegmentationManual.ui, src/Mod/ReverseEngineering/Gui/Workbench.cpp]
not_examined: []
