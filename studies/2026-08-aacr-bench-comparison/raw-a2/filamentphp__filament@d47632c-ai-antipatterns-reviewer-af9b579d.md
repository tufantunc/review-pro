<!-- filamentphp__filament@d47632c ai-antipatterns-reviewer; verbatim final answer -->
## AI-Antipatterns findings

- severity: Medium
  category: ai-antipatterns.ignored-convention
  file: packages/support/src/helpers.php
  line: 185
  title: Uses invade() to call Grammar's protected wrapJsonFieldAndPath() and rebuilds json_extract by hand, when the public wrap() already handles `->`
  evidence: |
    if (in_array($driverName, ['mysql', 'mariadb'], true) && str_contains($column, '->')) {
        [$field, $path] = invade($databaseConnection->getQueryGrammar())->wrapJsonFieldAndPath($column); /** @phpstan-ignore-line */

        $column = "json_extract({$field}{$path})";
    }
  evidence_refs: [packages/panels/src/helpers.php:30, packages/actions/src/Concerns/CanImportRecords.php:411, packages/support/composer.json:22]
  impact: |
    The change assumes the only way to turn `data->name` into SQL is to reach into a protected internal and assemble the expression itself. Laravel's public API already does this. The following comes from my knowledge of Laravel 10/11 because vendor/ is not installed, so I could not check it locally. `Illuminate\Database\Query\Grammars\Grammar::wrap()` is public. It detects `->` through `isJsonSelector()` and sends it to `wrapJsonSelector()`. `MySqlGrammar::wrapJsonSelector()` (which `MariaDbGrammar` inherits) is implemented as `[$field, $path] = $this->wrapJsonFieldAndPath($value); return 'json_unquote(json_extract('.$field.$path.'))';`. That leaves two problems:
    (1) The change depends on a protected method with no BC guarantee across the `^10.45|^11.0` range, and needs `invade()` plus a phpstan suppression only because it skips the public method.
    (2) The hand-built copy leaves out `json_unquote`. `lower(json_extract(...))` therefore compares against the JSON-encoded value, which keeps its surrounding quotes and escape sequences. Search terms containing `"` or `\` will not match the way the framework's own JSON selector would. The `str_contains($column, '->')` check also copies `isJsonSelector()` from the grammar.
    I am not flagging the `invade(...)->x(); /** @phpstan-ignore-line */` pattern itself. The repo already uses it at panels/src/helpers.php:30 and CanImportRecords.php:411, and spatie/invade is a declared dependency. The problem is that the public method exists, so there is no need for that pattern here.
  remedy: |
    Replace the block with the public grammar call and drop `invade` and the phpstan ignore:
      if (in_array($driverName, ['mysql', 'mariadb'], true) && str_contains($column, '->')) {
          $column = $databaseConnection->getQueryGrammar()->wrap($column);
      }
    This produces `json_unquote(json_extract(`data`, '$."name"'))`. The existing `str($column)->contains('(')` check at line 200 still wraps the result in an `Expression`. Add a MySQL test that searches a JSON column with a value containing a quote.
  confidence: medium
  overlap_hints: [correctness.logic, craft.boundary, dry.canonical-helper]

Other things I checked and did not flag:
- The `/** @phpstan-ignore-line */` placement after an `invade()` call follows the existing repo convention (panels/src/helpers.php:30, actions/src/Concerns/CanImportRecords.php:411). `phpstan.neon.dist` has no centralized ignore for this kind of call.
- `invade()` is not a new dependency. It is declared in packages/support/composer.json:22 and used in 5 other places.
- `wrapJsonFieldAndPath` is a real method, protected and returning `[$field, $path]`, so the call is not a hallucinated API. This is also from my knowledge of Laravel, not verified locally.

## Files examined
examined: [packages/support/src/helpers.php]
not_examined: []
