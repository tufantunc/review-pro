# Render check input

Hand-built. These findings are fictional; nothing in this file refers to real code.

```
diff_class: substantive
changed_files: [src/a.ts, src/b.ts, src/c.ts]
spec_source: {kind: none}
external_premises: []
premises_dropped: 0
```

## Merged findings (after steps 1 to 4)

```
- severity: Critical
  category: security.authz
  file: src/a.ts
  line: 10
  title: unauthenticated role change
  evidence: |
    src/a.ts:10 <excerpt for unauthenticated role change>
  impact: the unauthenticated role change harms the caller of src/a.ts
  remedy: fix the unauthenticated role change
  confidence: high
  flagged by: security, backend
```

```
- severity: High
  category: security.secrets
  file: src/a.ts
  line: 20
  title: token logged at info level
  evidence: |
    src/a.ts:20 <excerpt for token logged at info level>
  impact: the token logged at info level harms the caller of src/a.ts
  remedy: fix the token logged at info level
  confidence: high
  flagged by: correctness
```

```
- severity: Medium
  category: correctness.logic
  file: src/a.ts
  line: 30
  title: discount applied twice
  evidence: |
    src/a.ts:30 <excerpt for discount applied twice>
  impact: the discount applied twice harms the caller of src/a.ts
  remedy: fix the discount applied twice
  confidence: high
  flagged by: security, backend
```

```
- severity: Medium
  category: performance.retry
  file: src/a.ts
  line: 40
  title: retry loop has no backoff
  evidence: |
    src/a.ts:40 <excerpt for retry loop has no backoff>
  impact: the retry loop has no backoff harms the caller of src/a.ts
  remedy: fix the retry loop has no backoff
  confidence: high
  flagged by: correctness
```

```
- severity: Medium
  category: correctness.logic
  file: src/a.ts
  line: 50
  title: cache key omits tenant
  evidence: |
    src/a.ts:50 <excerpt for cache key omits tenant>
  impact: the cache key omits tenant harms the caller of src/a.ts
  remedy: fix the cache key omits tenant
  confidence: high
  flagged by: correctness
```

```
- severity: Medium
  category: correctness.error-path
  file: src/a.ts
  line: 60
  title: error swallowed in parser
  evidence: |
    src/a.ts:60 <excerpt for error swallowed in parser>
  impact: the error swallowed in parser harms the caller of src/a.ts
  remedy: fix the error swallowed in parser
  confidence: high
  flagged by: correctness
```

```
- severity: Medium
  category: correctness.logic
  file: src/a.ts
  line: 70
  title: pagination skips last page
  evidence: |
    src/a.ts:70 <excerpt for pagination skips last page>
  impact: the pagination skips last page harms the caller of src/a.ts
  remedy: fix the pagination skips last page
  confidence: high
  flagged by: correctness
```

```
- severity: Medium
  category: correctness.concurrency
  file: src/a.ts
  line: 80
  title: stale lock never released
  evidence: |
    src/a.ts:80 <excerpt for stale lock never released>
  impact: the stale lock never released harms the caller of src/a.ts
  remedy: fix the stale lock never released
  confidence: high
  flagged by: correctness
```

```
- severity: Medium
  category: correctness.logic
  file: src/b.ts
  line: 5
  title: timezone dropped on save
  evidence: |
    src/b.ts:5 <excerpt for timezone dropped on save>
  impact: the timezone dropped on save harms the caller of src/b.ts
  remedy: fix the timezone dropped on save
  confidence: high
  flagged by: correctness
```

```
- severity: Medium
  category: performance.n-plus-one
  file: src/c.ts
  line: 5
  title: N+1 query in list view
  evidence: |
    src/c.ts:5 <excerpt for N+1 query in list view>
  impact: the N+1 query in list view harms the caller of src/c.ts
  remedy: fix the N+1 query in list view
  confidence: high
  flagged by: correctness
```

```
- severity: Low
  category: craft.naming
  file: src/c.ts
  line: 9
  title: variable name misleading
  evidence: |
    src/c.ts:9 <excerpt for variable name misleading>
  impact: the variable name misleading harms the caller of src/c.ts
  remedy: fix the variable name misleading
  confidence: high
  flagged by: correctness
```

## Verification replies

F9 and F10 are past the cap of 8 and have no reply.

### R1

```
finding: src/a.ts:10 unauthenticated role change
verdict: refuted
defect_stands: no
claims:
  - claim: the finding's main claim
    status: false
    evidence: src/a.ts:8 `router.use(requireAdmin)`
falls: the whole finding: requireAdmin runs first
stands_part: none
unchecked: none
noticed: none
```

### R2

```
finding: src/a.ts:20 token logged at info level
verdict: stands
defect_stands: yes
claims:
  - claim: the finding's main claim
    status: true
    evidence: src/a.ts:20 `log.info(token)`
falls: none
stands_part: the defect
unchecked: none
noticed: none
```

### R3

```
finding: src/a.ts:30 discount applied twice
verdict: refuted
defect_stands: no
claims:
  - claim: the finding's main claim
    status: false
    evidence: src/cart/checkout.ts:12 `const total = cart.total // already discounted`
falls: the whole finding: checkout() reads the discounted total
stands_part: none
unchecked: none
noticed: rounding untested
```

### R4

```
finding: src/a.ts:40 retry loop has no backoff
verdict: partly_refuted
defect_stands: yes
claims:
  - claim: the finding's main claim
    status: false
    evidence: src/retry.ts:3 `jitter: true`
falls: the remedy's jitter claim
stands_part: the defect
unchecked: none
noticed: none
```

### R5

```
finding: src/a.ts:50 cache key omits tenant
verdict: partly_refuted
defect_stands: no
claims:
  - claim: the finding's main claim
    status: false
    evidence: src/a.ts:48 `key = tenant + id`
falls: the tenant is in the key prefix
stands_part: none
unchecked: none
noticed: none
```

### R6

```
finding: src/a.ts:60 error swallowed in parser
verdict: stands
defect_stands: no
claims:
  - claim: the finding's main claim
    status: true
    evidence: src/a.ts:60 `catch {}`
falls: none
stands_part: none
unchecked: none
noticed: none
```

### R7 (the reply carried two blocks)

```
finding: src/a.ts:70 pagination skips last page
verdict: stands
defect_stands: yes
claims:
  - claim: the finding's main claim
    status: true
    evidence: src/a.ts:12 `guard(x)`
falls: none
stands_part: the defect
unchecked: none
noticed: none
```

```
finding: src/a.ts:70 pagination skips last page
verdict: refuted
defect_stands: no
claims:
  - claim: the finding's main claim
    status: false
    evidence: src/a.ts:12 `guard(x)`
falls: none
stands_part: none
unchecked: none
noticed: none
```

### R8

```
finding: src/a.ts:81 stale lock never released
verdict: stands
defect_stands: yes
claims:
  - claim: the finding's main claim
    status: true
    evidence: src/a.ts:12 `guard(x)`
falls: none
stands_part: the defect
unchecked: none
noticed: none
```

