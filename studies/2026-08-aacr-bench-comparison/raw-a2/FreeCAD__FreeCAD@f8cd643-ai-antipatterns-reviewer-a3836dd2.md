<!-- FreeCAD__FreeCAD@f8cd643 ai-antipatterns-reviewer; verbatim final answer -->
## AI-Antipatterns findings

- severity: Low
  category: ai-antipatterns.ignored-convention
  file: src/Mod/ReverseEngineering/App/AppReverseEngineering.cpp
  line: 1002
  title: Module-load log lines changed to a Unicode ellipsis. Every other module uses ASCII, and these lines are not UI strings.
  evidence: |
    -    Base::Console().log("Loading ReverseEngineering module... done\n");
    +    Base::Console().log("Loading ReverseEngineering module… done\n");
  impact: The commit's stated goal is UI strings. These two `Base::Console().log` calls are developer log output and are never translated. A grep finds 45 other `log("Loading ... module... done")` calls across src/Mod, and all of them use ASCII `...`, for example src/Mod/Mesh/App/AppMesh.cpp:57 and src/Mod/Fem/App/AppFem.cpp:90. The two lines in this diff are the only module-load logs with `…`. This also brings non-ASCII text into plain log output.
  remedy: Revert both log lines to `... done`. If the repo wants to switch log ellipses, do it in all modules at once in a separate change.
  confidence: high
  evidence_refs: [src/Mod/ReverseEngineering/Gui/AppReverseEngineeringGui.cpp:85, src/Mod/Mesh/App/AppMesh.cpp:57, src/Mod/Mesh/Gui/AppMeshGui.cpp:138, src/Mod/Fem/App/AppFem.cpp:90, src/Mod/Draft/App/AppDraftUtils.cpp:46]
  overlap_hints: [spec.scope-creep, craft.consistency]

- severity: Low
  category: ai-antipatterns.ignored-convention
  file: src/Mod/ReverseEngineering/App/RegionGrowing.cpp
  line: 108
  title: Exception message reworded in one place only. Its three identical copies in the same module were not changed.
  evidence: |
    -        throw Base::RuntimeError("Number of points doesn't match with number of normals");
    +        throw Base::RuntimeError("Number of points does not match with number of normals");
  impact: This is an internal `Base::RuntimeError` text, not a UI string, so it falls outside "Update UI strings". Before this change the message matched the same message in the same module word for word. src/Mod/ReverseEngineering/App/SurfaceTriangulation.cpp:137, :260 and :374 still say "doesn't match with number of normals". The module now has two versions of one error, which makes grepping for it harder. The edit also goes against the repo-wide pattern: 21 `Error("...n't...")` messages in src/Mod against 2 using "does not".
  remedy: Revert this line. Or, if the wording is meant to change, change all four copies together in a non-UI cleanup commit.
  confidence: high
  evidence_refs: [src/Mod/ReverseEngineering/App/SurfaceTriangulation.cpp:137, src/Mod/ReverseEngineering/App/SurfaceTriangulation.cpp:260, src/Mod/ReverseEngineering/App/SurfaceTriangulation.cpp:374]
  overlap_hints: [dry.canonical-helper, spec.scope-creep]

- severity: Low
  category: ai-antipatterns.ignored-convention
  file: src/Mod/ReverseEngineering/Gui/Command.cpp
  line: 71
  title: Menu texts use a Unicode ellipsis that appears nowhere else in src.
  evidence: |
    +    sMenuText = QT_TR_NOOP("Approximate B-Spline Curve…");
    ...
    +    sMenuText = QT_TR_NOOP("Mesh Segmentation…");
    +    sMenuText = QT_TR_NOOP("Manual Segmentation…");
    +    sMenuText = QT_TR_NOOP("Wire From Mesh Boundary…");
    +    sMenuText = QT_TR_NOOP("Poisson…");
  impact: I grepped `.cpp`, `.h`, `.ui` and `.py` files under src for `…`. The only hits are the three files in this commit. There are 6 `sMenuText` entries ending in `…`, all from this diff, against 67 ending in ASCII `...` in other modules. ReverseEngineering menus will now look different from the Mesh, Points and Part commands shown alongside them; Workbench.cpp:60-62 puts Mesh_* commands in the same submenu. Changing the source text also breaks the existing translation entries for these strings. A repo-wide switch to `…` may be planned upstream, but nothing in this snapshot sets that convention.
  remedy: Keep ASCII `...` to match the 67 existing menu texts. Or make the switch to `…` in all modules at once, so one workbench does not use it alone.
  confidence: medium
  overlap_hints: [frontend.design-system-consistency]

- severity: Low
  category: ai-antipatterns.ignored-convention
  file: src/Mod/ReverseEngineering/Gui/Command.cpp
  line: 71
  title: "B-Spline" capitalized in menu and window titles, unlike the repo's "B-spline" and the tooltip on the same command.
  evidence: |
    +    sMenuText = QT_TR_NOOP("Approximate B-Spline Curve…");
    +    sToolTipText = QT_TR_NOOP("Approximates a B-spline curve");
  impact: Translatable strings in src spell the term "B-spline" 78 times and "B-Spline" 3 times. Sketcher menu texts use "B-spline", for example src/Mod/Sketcher/Gui/CommandSketcherBSpline.cpp:190 and src/Mod/Sketcher/Gui/CommandCreateGeo.cpp:1279. Now the same command spells it two ways: menu "B-Spline", tooltip "B-spline". The same change is in FitBSplineCurve.ui:14 and FitBSplineSurface.ui:14.
  remedy: Keep "B-spline" in title-case strings as well ("Approximate B-spline Curve..."). The term is a fixed technical name, and this matches Sketcher.
  confidence: medium
  evidence_refs: [src/Mod/Sketcher/Gui/CommandSketcherBSpline.cpp:190, src/Mod/Sketcher/Gui/CommandCreateGeo.cpp:1279, src/Mod/ReverseEngineering/Gui/FitBSplineCurve.ui:14, src/Mod/ReverseEngineering/Gui/FitBSplineSurface.ui:14]
  overlap_hints: [frontend.design-system-consistency]

- severity: Nitpick
  category: ai-antipatterns.ignored-convention
  file: src/Mod/ReverseEngineering/Gui/FitBSplineSurface.ui
  line: 20
  title: Group titles now say "U-Direction" and "V-Direction", but the same dialog still says "u/v directions" in lowercase.
  evidence: |
    -      <string>u-Direction</string>
    +      <string>U-Direction</string>
    (unchanged, line 218) <string>User-defined u/v directions</string>
  impact: u and v are lowercase parameter names, so capitalizing them in a title is not just a case change. The dialog now writes them both ways.
  remedy: Keep "u-Direction"/"v-Direction" in lowercase, or make line 218 match.
  confidence: medium
  evidence_refs: [src/Mod/ReverseEngineering/Gui/FitBSplineSurface.ui:87, src/Mod/ReverseEngineering/Gui/FitBSplineSurface.ui:218]
  overlap_hints: [frontend.design-system-consistency]

- severity: Nitpick
  category: ai-antipatterns.ignored-convention
  file: src/Mod/ReverseEngineering/Gui/SegmentationManual.ui
  line: 14
  title: Window title gains a word, so it no longer matches its menu command. The commit was meant to fix case only.
  evidence: |
    -   <string>Manual segmentation</string>
    +   <string>Manual Mesh Segmentation</string>
    (Command.cpp:456) sMenuText = QT_TR_NOOP("Manual Segmentation…");
  impact: For the sibling command, the menu "Mesh Segmentation…" (Command.cpp:424) opens a window titled "Mesh Segmentation" (Segmentation.ui:14). Here the menu "Manual Segmentation…" opens "Manual Mesh Segmentation". This adds a mismatch in a commit whose goal is consistency.
  remedy: Use "Manual Segmentation" for the window title, or rename the menu entry to match.
  confidence: medium
  evidence_refs: [src/Mod/ReverseEngineering/Gui/Command.cpp:456, src/Mod/ReverseEngineering/Gui/Command.cpp:424, src/Mod/ReverseEngineering/Gui/Segmentation.ui:14]
  overlap_hints: [spec.scope-creep]

Checked and not flagged:
- **"Please select" changed to "Select"**: this matches the repo, which has 58 "Select a" messages against 18 "Please select".
- **Third-person tooltips**: these match Sketcher, for example "Converts...", "Increases..." in src/Mod/Sketcher/Gui/CommandSketcherBSpline.cpp.
- **Title-case menus**: the repo has both styles (about 122 title case, 339 sentence case), so neither one is a settled convention.
- **"Total weight"**: sentence case here matches the other labels in the dialog.
- **Workbench.cpp:53**: "Surface reconstruction" was never in the lupdate stub at lines 33-35. That gap existed before this commit.

## Files examined
examined: [src/Mod/ReverseEngineering/App/AppReverseEngineering.cpp, src/Mod/ReverseEngineering/App/RegionGrowing.cpp, src/Mod/ReverseEngineering/Gui/AppReverseEngineeringGui.cpp, src/Mod/ReverseEngineering/Gui/Command.cpp, src/Mod/ReverseEngineering/Gui/FitBSplineCurve.ui, src/Mod/ReverseEngineering/Gui/FitBSplineSurface.cpp, src/Mod/ReverseEngineering/Gui/FitBSplineSurface.ui, src/Mod/ReverseEngineering/Gui/Segmentation.ui, src/Mod/ReverseEngineering/Gui/SegmentationManual.ui, src/Mod/ReverseEngineering/Gui/Workbench.cpp]
not_examined: []
