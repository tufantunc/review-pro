<!-- FreeCAD__FreeCAD@f8cd643 frontend-reviewer; verbatim final answer -->
## Frontend findings

- severity: Medium
  category: frontend.i18n
  file: src/Mod/ReverseEngineering/Gui/Workbench.cpp
  line: 53
  title: The renamed "Surface Reconstruction" submenu is never registered for translation, so it always shows in English
  evidence: |
    #if 0  // needed for Qt's lupdate utility
        qApp->translate("Workbench", "Reverse Engineering");
    #endif
    ...
        reen->setCommand("&Reverse Engineering");
    ...
        reconstruct->setCommand("Surface Reconstruction");
    ...
        segm->setCommand("Segmentation");
    ...
        approx->setCommand("Approximation");
  impact: MenuManager translates submenu names with `QApplication::translate("Workbench", menuName.c_str())` (src/Gui/MenuManager.cpp:244, :295). The "Workbench" context in ReverseEngineering.ts contains only "Reverse Engineering" (ts:583-589). So "Surface Reconstruction", "Segmentation", "Approximation" and "&Reverse Engineering" (the ampersand makes it a different key) always appear in English. The commit recased the string on line 53 without making it translatable. The Mesh workbench registers every submenu name (src/Mod/Mesh/Gui/Workbench.cpp:44-55).
  remedy: Add `qApp->translate("Workbench", "&Reverse Engineering")`, `"Surface Reconstruction"`, `"Segmentation"` and `"Approximation"` to the `#if 0` lupdate block, following the Mesh workbench, then regenerate the .ts file.
  confidence: high
  evidence_refs: [src/Gui/MenuManager.cpp:244, src/Gui/MenuManager.cpp:295, src/Mod/ReverseEngineering/Gui/Resources/translations/ReverseEngineering.ts:583, src/Mod/Mesh/Gui/Workbench.cpp:44]
  overlap_hints: [correctness]

- severity: Low
  category: frontend.consistency
  file: src/Mod/ReverseEngineering/Gui/Command.cpp
  line: 536
  title: "Wire From Mesh Boundary…" has an ellipsis but runs immediately without opening a dialog
  evidence: |
    sMenuText = QT_TR_NOOP("Wire From Mesh Boundary…");
    ...
    void CmdMeshBoundary::activated(int)
    {
        std::vector<Mesh::Feature*> objs = Gui::Selection().getObjectsOfType<Mesh::Feature>();
        App::Document* document = App::GetApplication().getActiveDocument();
        document->openTransaction("Wire from mesh");
  impact: The commit applies the ellipsis-means-dialog rule to the other commands: the ones that open a task dialog keep "…" and "Plane", "Cylinder", "From Components" etc. have none. This command creates the wire or face directly (Command.cpp:542-587) with no task dialog or prompt, so its ellipsis is wrong. Also, "From" is capitalised mid-title, while other title-cased menus lowercase short prepositions (TechDraw uses "Remove View from Clip Group").
  remedy: Use `"Wire from Mesh Boundary"` with no ellipsis. Write "from" in lowercase if the project's title-case rule lowercases prepositions.
  confidence: high (ellipsis), low (preposition)
  evidence_refs: [src/Mod/ReverseEngineering/Gui/Command.cpp:542]
  overlap_hints: []

- severity: Low
  category: frontend.consistency
  file: src/Mod/ReverseEngineering/Gui/SegmentationManual.ui
  line: 14
  title: The commit makes the manual segmentation dialog title differ from its menu text
  evidence: |
    -   <string>Manual segmentation</string>
    +   <string>Manual Mesh Segmentation</string>
    (Command.cpp:456)  sMenuText = QT_TR_NOOP("Manual Segmentation…");
  impact: Before this change, the menu text and the task-panel title matched apart from case. Now the user clicks "Manual Segmentation…" and sees a panel titled "Manual Mesh Segmentation". The approximation commands have the same kind of mismatch from before ("Approximate B-Spline Curve…" opens "Fit B-Spline Curve", Command.cpp:71 vs FitBSplineCurve.ui:14; the same for Surface at :104 vs FitBSplineSurface.ui:14). The commit edited both sides of each pair and left them different.
  remedy: Make each menu text and dialog title the same: either "Manual Mesh Segmentation…" in the menu or "Manual Segmentation" as the title. Pick either "Approximate" or "Fit" for the B-spline commands and their dialogs.
  confidence: high
  evidence_refs: [src/Mod/ReverseEngineering/Gui/Command.cpp:456, src/Mod/ReverseEngineering/Gui/Command.cpp:71, src/Mod/ReverseEngineering/Gui/FitBSplineCurve.ui:14, src/Mod/ReverseEngineering/Gui/Command.cpp:104, src/Mod/ReverseEngineering/Gui/FitBSplineSurface.ui:14]
  overlap_hints: []

- severity: Low
  category: frontend.consistency
  file: src/Mod/ReverseEngineering/Gui/Command.cpp
  line: 602
  title: Two tooltips were not converted to the "verb-s" form the commit uses everywhere else
  evidence: |
    sMenuText = QT_TR_NOOP("Poisson…");
    sToolTipText = QT_TR_NOOP("Poisson surface reconstruction");
    ...
    sMenuText = QT_TR_NOOP("Structured Point Clouds");
    sToolTipText = QT_TR_NOOP("Triangulation of structured point clouds");
    sStatusTip = QT_TR_NOOP("Triangulation of structured point clouds");
  impact: Every other tooltip in this workbench was changed to "Approximates…" or "Creates…". These two are still noun phrases, so this group of menu tooltips is mixed. Line 637 also repeats the tooltip as a separate literal instead of using `sStatusTip = sToolTipText` like the other commands, so the two strings can drift apart.
  remedy: For example, use "Reconstructs a surface from a point cloud using the Poisson method" and "Triangulates structured point clouds", and set `sStatusTip = sToolTipText;`.
  confidence: high
  overlap_hints: []

- severity: Low
  category: frontend.i18n
  file: src/Mod/ReverseEngineering/Gui/Command.cpp
  line: 84
  title: Edited warning messages still use another command's translation context
  evidence: |
    // inside CmdApproxCurve::activated
    qApp->translate("Reen_ApproxSurface", "Select a point cloud."));
    // inside CmdPoissonReconstruction::activated (line 615)
    qApp->translate("Reen_ApproxSurface", "Select a single point cloud."));
  impact: The curve and Poisson commands file their messages under the "Reen_ApproxSurface" context. Translators see these strings grouped under the wrong command and have no hint about where they appear. The commit rewrote all of these source strings, so translators must redo them anyway; that was the cheapest moment to fix the context.
  remedy: Use "Reen_ApproxCurve" and "Reen_PoissonReconstruction" as the contexts in their own commands, matching how CmdViewTriangulation uses "Reen_ViewTriangulation" at line 668.
  confidence: high
  overlap_hints: []

- severity: Low
  category: frontend.i18n
  file: src/Mod/ReverseEngineering/Gui/Command.cpp
  line: 496
  title: Undo transaction names in this workbench are not marked for translation
  evidence: |
    doc->openTransaction("Segmentation");
    ...
    document->openTransaction("Wire from mesh");
  impact: These names appear in the Undo/Redo menu. Other commands in the same file mark theirs with `openCommand(QT_TRANSLATE_NOOP("Command", "Fit plane"))` (lines 227, 259, 327, 376, 646). These two are not marked, so they always show in English and sit outside the commit's consistency pass.
  remedy: Wrap the names with `QT_TRANSLATE_NOOP("Command", ...)`, or use `openCommand`/`commitCommand` like the other commands.
  confidence: medium
  evidence_refs: [src/Mod/ReverseEngineering/Gui/Command.cpp:546, src/Mod/ReverseEngineering/Gui/Command.cpp:227]
  overlap_hints: []

- severity: Low
  category: frontend.consistency
  file: src/Mod/ReverseEngineering/Gui/Command.cpp
  line: 71
  title: The new style (Unicode ellipsis, title case, "B-Spline") appears in this workbench only
  evidence: |
    sMenuText = QT_TR_NOOP("Approximate B-Spline Curve…");
    (Sketcher)  sMenuText = QT_TR_NOOP("Create B-spline");
    (Part)      sMenuText = QT_TR_NOOP("Convert geometry to B-spline");
    (Mesh)      sMenuText = QT_TR_NOOP("Create mesh from shape...");
  impact: A grep of src/ finds 121 menu texts ending in ASCII "..." and no "…" outside ReverseEngineering. Menu texts elsewhere are in sentence case and write "B-spline". Some of these commands share a menu with Mesh commands: the Segmentation submenu contains Mesh_RemeshGmsh, Mesh_VertexCurvature and Mesh_CurvatureInfo. That menu therefore mixes the two styles until the rest of the repo is converted.
  remedy: If this is the first step of a repo-wide convention, write it down in the contribution or UI-strings guidelines and track converting the other workbenches. Otherwise, keep the existing repo convention.
  confidence: medium
  evidence_refs: [src/Mod/Mesh/Gui/Command.cpp:530, src/Mod/ReverseEngineering/Gui/Workbench.cpp:60]
  overlap_hints: []

- severity: Nitpick
  category: frontend.consistency
  file: src/Mod/ReverseEngineering/Gui/FitBSplineSurface.ui
  line: 20
  title: The u/v parameter symbols are now uppercase in group titles but lowercase elsewhere in the same dialog
  evidence: |
    -      <string>u-Direction</string>
    +      <string>U-Direction</string>
    ...
             <string>User-defined u/v directions</string>
  impact: In surface parametrisation, u and v are lowercase symbols. Title-casing them makes the group titles (lines 20 and 87) disagree with the checkbox at line 218 in the same dialog.
  remedy: Keep the symbols lowercase, for example "u-Direction" and "v-Direction", or write "U Direction" in all three places.
  confidence: medium
  overlap_hints: []

- severity: Nitpick
  category: frontend.consistency
  file: src/Mod/ReverseEngineering/App/AppReverseEngineering.cpp
  line: 1002
  title: A developer log line was given the UI ellipsis rule and now differs from every other module's load message
  evidence: |
    Base::Console().log("Loading ReverseEngineering module… done\n");
    (Mesh/App/AppMesh.cpp:57)  Base::Console().log("Loading Mesh module... done\n");
  impact: This log line is untranslated and not shown in the UI. Every other module prints "module... done" with ASCII dots (Mesh, DraftUtils, TestGui), so a log search for that pattern now misses ReverseEngineering. The same applies to AppReverseEngineeringGui.cpp:85.
  remedy: Revert the two Console().log strings to ASCII "...".
  confidence: medium
  evidence_refs: [src/Mod/Mesh/App/AppMesh.cpp:57, src/Mod/ReverseEngineering/Gui/AppReverseEngineeringGui.cpp:85]
  overlap_hints: []

## Files examined
examined: [src/Mod/ReverseEngineering/App/AppReverseEngineering.cpp, src/Mod/ReverseEngineering/App/RegionGrowing.cpp, src/Mod/ReverseEngineering/Gui/AppReverseEngineeringGui.cpp, src/Mod/ReverseEngineering/Gui/Command.cpp, src/Mod/ReverseEngineering/Gui/FitBSplineCurve.ui, src/Mod/ReverseEngineering/Gui/FitBSplineSurface.cpp, src/Mod/ReverseEngineering/Gui/FitBSplineSurface.ui, src/Mod/ReverseEngineering/Gui/Segmentation.ui, src/Mod/ReverseEngineering/Gui/SegmentationManual.ui, src/Mod/ReverseEngineering/Gui/Workbench.cpp]
not_examined: []
