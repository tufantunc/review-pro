<!-- filamentphp__filament@d47632c db-reviewer; verbatim final answer -->
## DB findings

- severity: Medium
  category: db.query
  file: packages/support/src/helpers.php
  line: 187
  title: The forced case-insensitive search on a JSON path uses json_extract without json_unquote, so it matches against JSON text instead of the actual value
  evidence: |
    [$field, $path] = invade($databaseConnection->getQueryGrammar())->wrapJsonFieldAndPath($column); /** @phpstan-ignore-line */

    $column = "json_extract({$field}{$path})";
  impact: |
    This comes from my knowledge of MySQL/MariaDB and Laravel, not from vendor source (no vendor/ is installed). On MySQL, `JSON_EXTRACT` returns a JSON value. When `lower()` turns it into a string, that string still has its surrounding double quotes and JSON escaping: `"` becomes `\"`, `\` becomes `\\`, and control characters become `\n` and similar. So a search for `say "hi"` or for a path like `C:\dir` never matches the row it should. MariaDB is worse, because it stores JSON as LONGTEXT and `JSON_EXTRACT` returns the stored text as written. Laravel's `json_encode` escapes non-ASCII characters by default (`\u00e9`). So on MariaDB, a forced case-insensitive search for any accented or non-Latin text (`é`, `ş`, Cyrillic, CJK) in a `->` column returns no rows. `lower()` also changes the case of the hex escapes. Translatable fields are the usual non-ASCII JSON columns, so they are hit hardest. The `%term%` wildcards hide the quote problem for plain ASCII, so simple tests pass, but the results are wrong for the inputs above. Before this change, this path produced the raw `lower(data->en)`, which is invalid SQL on MySQL. The change turns an SQL error into a silent wrong result in these cases.
  remedy: |
    Unquote the value the way Laravel does: `$column = "json_unquote(json_extract({$field}{$path}))";`. Better, call the public grammar API instead of `invade` plus a phpstan ignore: `$column = $databaseConnection->getQueryGrammar()->wrap($column);`. For MySQL/MariaDB, Laravel's `MySqlGrammar::wrapJsonSelector` produces `json_unquote(json_extract(field, '$."path"'))`, which compares against the unquoted value. Add a test with a value that contains a `"` and a non-ASCII character.
  confidence: medium
  overlap_hints: [correctness.logic, craft.canonical-helper]

- severity: Low
  category: db.query
  file: packages/support/src/helpers.php
  line: 184
  title: The fix only covers MySQL/MariaDB, so forced case-insensitive search on `->` columns still builds invalid raw SQL on pgsql and sqlite
  evidence: |
    if (in_array($driverName, ['mysql', 'mariadb'], true) && str_contains($column, '->')) {
    ...
    $column = "lower({$column})";
  impact: |
    On pgsql, `data->en` becomes `lower(data->en::text)`. That is returned as a raw `Expression`, so the grammar never wraps it, and `en` is read as an identifier, not a JSON key. Postgres forces case-insensitive search by default (`'pgsql' => true` at line 179), so any searchable `->` column there gets an invalid expression. On sqlite, `lower(data->en)` is also not a valid JSON path. The bug the commit names ("fix forced lower case search") stays open on those drivers. This gap existed before the change and was not introduced by it.
  remedy: |
    Wrap `->` columns through the connection grammar for every driver, before the pgsql `::text` cast and the `lower()` call: `if (str_contains($column, '->')) { $column = $databaseConnection->getQueryGrammar()->wrap($column); }`. Each grammar's `wrapJsonSelector` then produces valid SQL for its driver.
  confidence: medium
  overlap_hints: [correctness.logic]

## Files examined
examined: [packages/support/src/helpers.php]
not_examined: []
