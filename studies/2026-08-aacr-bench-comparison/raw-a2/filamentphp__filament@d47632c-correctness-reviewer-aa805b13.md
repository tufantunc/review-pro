<!-- filamentphp__filament@d47632c correctness-reviewer; verbatim final answer -->
- severity: Low
  category: correctness.logic
  file: packages/support/src/helpers.php
  line: 187
  title: The new MySQL/MariaDB JSON search compares against the JSON-encoded value instead of the unquoted text
  evidence: |
    [$field, $path] = invade($databaseConnection->getQueryGrammar())->wrapJsonFieldAndPath($column); /** @phpstan-ignore-line */

    $column = "json_extract({$field}{$path})";
  impact: |
    This part relies on what I know of Laravel, because vendor/ is not installed. In Laravel 10/11, `MySqlGrammar::wrapJsonSelector()` returns `'json_unquote(json_extract('.$field.$path.'))'`. Its helper `wrapJsonFieldAndPath()` returns `` [`data`, ", '$.\"name\"'"] ``. The new code builds `lower(json_extract(...))` and leaves out `json_unquote`. That makes the search run on the JSON-encoded value: `"Foo \"Bar\""`, with the surrounding quotes and the escaped `"` and `\` characters. It does not run on `Foo "Bar"`.
    Ordinary substring searches still match because the quotes surround the value. Two kinds of search behave differently from the non-forced path, which uses `json_unquote`:
    - A search term that contains `"` or `\` never matches the stored value. For example, `say "hi"` against the stored `say \"hi\"` fails.
    - A term with a leading or trailing `"` matches the value's start or end, and a search for `null` matches JSON nulls.
    Only searches with case-insensitivity forced, on mysql or mariadb, with a `->` column are affected. Before this change that case was broken outright: `lower(data->name)` was raw SQL with an unquoted path.
  remedy: Use `"json_unquote(json_extract({$field}{$path}))"`, which matches what Laravel's MySQL grammar does for `->` columns. Another option is to call `wrapJsonSelector($column)` through invade directly. If leaving out the unquote is deliberate, to match how `SpatieLaravelTranslatableContentDriver` builds its expression, add a comment saying so.
  confidence: medium
  overlap_hints: [db.query-correctness]

- severity: Low
  category: correctness.logic
  file: packages/support/src/helpers.php
  line: 184
  title: The fix only covers mysql/mariadb; SQLite still builds invalid raw `lower(col->path)` SQL
  evidence: |
    if (in_array($driverName, ['mysql', 'mariadb'], true) && str_contains($column, '->')) {
  impact: |
    The table column search path turns relationship dot notation into `->` (packages/tables/src/Columns/Concerns/InteractsWithTableQuery.php:98-104). When `isSearchForcedCaseInsensitive(true)` is set on SQLite, or on any driver other than pgsql, mysql or mariadb, the result is still `new Expression("lower(data->name)")`. Because it is a raw Expression, Laravel's grammar never rewrites the `->` into `json_extract`. That SQL is not valid for SQLite, where `name` is read as a column identifier.
    So the bug this commit fixes is fixed on MySQL and MariaDB only. The deciding factor is the database driver. Filament's own SQLite test setup would not show the problem.
  remedy: Add `sqlite` to the driver list. Laravel's `SQLiteGrammar::wrapJsonSelector` also produces `json_extract(field, path)`, so the same expression works there. The more general option is to call the grammar's `wrapJsonSelector()` through invade for every driver other than pgsql.
  confidence: medium
  overlap_hints: [db.query-correctness]

I relied on Laravel knowledge, not source, for one point: in Laravel 10/11, `Grammar::wrapJsonFieldAndPath()` is protected and returns `[wrap(field), ", '$.\"path\"'"]`. That fits the generated `json_extract(field, '$."path"')`, so the change produces valid SQL. The unqualified `invade()` call inside the `Filament\Support` namespace falls back to the global function from spatie/invade. That package is a declared dependency (packages/support/composer.json:22), and its `__call` can call protected methods.

## Files examined
examined: [packages/support/src/helpers.php]
not_examined: []
