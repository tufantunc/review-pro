<!-- filamentphp__filament@d47632c craft-reviewer; verbatim final answer -->
## Craft findings

- severity: Medium
  category: craft.boundary
  file: packages/support/src/helpers.php
  line: 185
  title: The change reaches into the grammar's protected internals with invade() when the public wrap() already compiles `->` selectors
  evidence: |
    if (in_array($driverName, ['mysql', 'mariadb'], true) && str_contains($column, '->')) {
        [$field, $path] = invade($databaseConnection->getQueryGrammar())->wrapJsonFieldAndPath($column); /** @phpstan-ignore-line */

        $column = "json_extract({$field}{$path})";
    }
  impact: I couldn't check this against source because vendor/ isn't installed, so this comes from what I know of Laravel's Grammar API. In `Illuminate\Database\Grammar` and `Query\Grammars\MySqlGrammar`, the public `wrap()` already sends any value containing `->` to `wrapJsonSelector()`. On MySQL and MariaDB that calls `wrapJsonFieldAndPath()` itself and returns `json_unquote(json_extract(<field>, '$."path"'))`. The PR instead calls the protected step directly through `spatie/invade` and rebuilds the SQL by joining strings. This has three costs. (1) It ties a shared helper to a protected Laravel method that isn't part of the supported API, on two framework majors (`illuminate/*: ^10.45|^11.0`). (2) It needs a blanket `@phpstan-ignore-line`, so static analysis no longer covers that whole line. (3) It copies grammar logic by hand and leaves out the `json_unquote` step that `wrap()` adds. The repo uses `invade()` in five other places: `tables/.../HasQuery.php:125`, `tables/.../HasRecords.php:80`, `panels/src/helpers.php:30`, `actions/.../CanImportRecords.php:401` and `:411`. Most of those (`aliasedPivotColumns`, `hydratePivotRelation`, `callBeforeCallbacks`, the S3 adapter client) reach internals that have no public equivalent. Here a public equivalent exists.
  remedy: Use the public API instead. Replace the two lines with `$column = $databaseConnection->getQueryGrammar()->wrap($column);`. That removes the `invade()` call, the destructuring, the hand-built `json_extract(...)` string and the phpstan suppression. `wrap()` also handles a qualified `table.column->path`, which matters because `AttachAction` and `AssociateAction` pass `$query->qualifyColumn(...)` (`AttachAction.php:232`, `AssociateAction.php:230`). One behaviour difference: the result includes `json_unquote`, so `lower()` runs on the plain string, not the quoted JSON literal. That is the more correct input for `lower()`/`LIKE`. Confirm the existing JSON search tests still pass.
  confidence: medium
  overlap_hints: [api-contract.type-boundary, ai-antipatterns.ignored-conventions, correctness.logic]
  evidence_refs: [packages/panels/src/helpers.php:30, packages/tables/src/Table/Concerns/HasQuery.php:125, packages/tables/src/Concerns/HasRecords.php:80, packages/actions/src/Concerns/CanImportRecords.php:401, packages/actions/src/Concerns/CanImportRecords.php:411, packages/tables/src/Actions/AttachAction.php:232, packages/support/composer.json:22]

- severity: Low
  category: craft.spaghetti
  file: packages/support/src/helpers.php
  line: 184
  title: A fourth driver-specific branch is nested inside the case-insensitivity branch of `generate_search_column_expression`
  evidence: |
    if ($isSearchForcedCaseInsensitive) {
        if (in_array($driverName, ['mysql', 'mariadb'], true) && str_contains($column, '->')) {
  impact: The function already applies three separate per-driver steps (`match ($driverName)` for pgsql quoting, `::text` and the case-insensitivity default). This adds a fourth, nested under the `lower()` flag, so the JSON column is only compiled when a search is forced case-insensitive. Turning JSON paths into SQL is not really a case-sensitivity concern. Putting it here means the JSON path stays raw in every other search path. The new `json_extract(` also interacts with the `str($column)->contains('json_extract(')` check above it, and with the `contains('(')` check below that returns an Expression. To follow what happens you have to trace string contents through several steps.
  remedy: Do the JSON compilation once, near the top of the function, using the grammar: `if (str_contains($column, '->')) { $column = $grammar->wrap($column); }`, limited to drivers whose earlier steps don't conflict. Then `lower()` only wraps an already-compiled expression and makes no driver checks of its own. If that would change non-forced searches too much for this PR, at least pull the step out into a small `compile_json_search_column()` so `generate_search_column_expression` doesn't take on another inline special case.
  confidence: medium
  overlap_hints: [correctness.logic]

## Files examined
examined: [packages/support/src/helpers.php]
not_examined: []
