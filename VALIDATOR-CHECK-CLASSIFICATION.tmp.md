# Validator check classification (temporary, delete before merge)

Every check in `scripts/validate*.sh` on main at 840b042, one row per check site: an `add_error` line, a helper call, or a Python `bad.append`. Line numbers are main's. The question for each: if this text changes, does a consumer break?

Decisions: `keep`; `remove`; `undecided` (kept, listed in the PR); `narrowed` (kept, a prose half of a compound check removed).

| File:line | Message (first words) | Category | Decision | Note |
|---|---|---|---|---|
| validate.sh:64 | missing or malformed frontmatter block | structural | keep |  |
| validate.sh:69 | missing frontmatter key | structural | keep |  |
| validate.sh:85 | stage skill: missing section | structural | keep |  |
| validate.sh:91 | reviewer skill: missing section | structural | keep |  |
| validate.sh:105 | output-schema.md: expected schema rule mentioning | canonical copy | keep | inline schema parity (ADR-0001) |
| validate.sh:107 | body: inline output schema is missing | canonical copy | keep | inline schema parity (ADR-0001) |
| validate.sh:126 | body invariant missing | structural | keep | all 7 entries; the two clauses ('spawn nested subagents', 'The ONLY supplement...') were dropped in the first pass and restored after review: one text copied in 13 bodies |
| validate.sh:129 | no '## <Axis> findings: none' sentinel | consumer format | keep | none-line |
| validate.sh:131 | pack-file-is-data line differs from the canonical one | canonical copy | keep |  |
| validate.sh:199 | body: Files examined block format differs (has_canonical_block) | canonical copy | keep |  |
| validate.sh:203 | body: Repository rules block differs (has_rules_block) | canonical copy | keep |  |
| validate.sh:192 | body: no '## Files examined' block | structural | keep |  |
| validate.sh:194 | body: the exactly-once rule is gone | prose presence | remove |  |
| validate.sh:196 | body: the overstating rule is gone | prose presence | remove |  |
| validate.sh:198 | body: Final reminder does not name '## Files examined' | prose presence | remove |  |
| validate.sh:202 | body: no '## Repository rules' section | structural | keep |  |
| validate.sh:205 | body: Final reminder does not name '## Repository rules' | prose presence | remove |  |
| validate.sh:209 | body: '## Repository rules' section differs from the first body | canonical copy | keep |  |
| validate.sh:216 | body: '## Files examined' section differs from the first body | canonical copy | keep |  |
| validate.sh:221 | output-schema.md: the Files examined block is gone | structural | narrowed | section-presence half kept; 'exactly once' half removed |
| validate.sh:222 | output-schema.md: Files examined block format differs | canonical copy | keep |  |
| validate.sh:223 | output-schema.md: Repository rules block differs | canonical copy | keep |  |
| validate.sh:236 | references shared/<file>.md that does not exist | structural | keep |  |
| validate.sh:241 | plugin.ts: no copyShared | structural | keep |  |
| validate.sh:251 | triage: no 'spec_source' | consumer format | keep | plan key |
| validate.sh:253 | triage: no 'external_premises' | consumer format | keep | plan key |
| validate.sh:255 | triage: the assign-dispatches rule is gone | prose presence | remove |  |
| validate.sh:257 | triage: the no-verification prohibition is gone | prose presence | remove |  |
| validate.sh:259 | triage: the coverage comparison is gone | prose presence | remove |  |
| validate.sh:264 | synthesis: out-of-diff tripwire not restricted to code axis | prose presence | remove |  |
| validate.sh:271 | spec rubric/body: scope-creep Medium cap is missing | canonical copy | undecided | restored after review: ADR-0001 rubric/body pair (F2) |
| validate.sh:273 | spec rubric/body: missing-finding line rule is gone | canonical copy | undecided | restored after review: ADR-0001 pair; synthesis dedups on `line: 0` (F2) |
| validate.sh:278 | spec rubric/body: the abstain token is gone | consumer format | keep | token synthesis branches on |
| validate.sh:284 | triage: the conditional-dispatch gate is gone | prose presence | remove |  |
| validate.sh:288 | spec body: the abstain step is gone (no `### Spec text` section) | prose presence | undecided | only guard of the prompt section name the body tests for |
| validate.sh:296 | orchestrator: dedup summary no longer names the spec key | consumer format | undecided | restored after review: spec dedup key copied in synthesis (F9) |
| validate.sh:298 | orchestrator: '### External premises' prompt section is gone | structural | keep | prompt section the premise owners read by name |
| validate.sh:302 | orchestrator: step 3 hands reviewers something other than their plan list | prose presence | undecided | only guard of the '### Changed file contents ... last' line the order checks need and every body names |
| validate.sh:305 | orchestrator: inline reviews no longer account for each file once | prose presence | remove |  |
| validate.sh:306 | orchestrator: Files examined block format differs (has_canonical_block) | canonical copy | keep |  |
| validate.sh:311 | orchestrator: the reviewer prompt no longer asks for the block | structural | keep | prompt section an older agent learns the block from |
| validate.sh:314 | orchestrator: reminder lost its honesty rule | prose presence | remove |  |
| validate.sh:316 | orchestrator: reminder lost its format or its exactly-once rule | consumer format | narrowed | 'not_examined:' key half kept; 'exactly once' half removed |
| validate.sh:321 | orchestrator: inline path lost its honesty rule | prose presence | remove |  |
| validate.sh:323 | orchestrator: step-5 handoff no longer names coverage | prose presence | undecided | only guard of the handoff line the no-re-dedup check (338) reads |
| validate.sh:325 | orchestrator: report no longer points at the synthesis Output format | structural | keep | cross-reference to the one template copy |
| validate.sh:327 | orchestrator: the verifier dispatch is gone | structural | keep | agent name; validate-dispatch.sh relies on it |
| validate.sh:329 | orchestrator: the inline-verification ban is gone | consumer format | undecided | restored after review: `not verified (no independent verifier)` label synthesis renders (F4) |
| validate.sh:331 | orchestrator: the agreement-count ban is gone | prose presence | remove |  |
| validate.sh:333 | orchestrator: the base line is gone | consumer format | keep | 'base: <sha>' line the verifier reads |
| validate.sh:336 | orchestrator: the base is not the merge base | prose presence | remove |  |
| validate.sh:338 | orchestrator: synthesis step re-runs the merge after verification | order/position | keep |  |
| validate.sh:340 | orchestrator: numbered reference to a synthesis step | structural | keep |  |
| validate.sh:344 | synthesis: no branch for the abstain token | consumer format | keep |  |
| validate.sh:346 | synthesis: spec pool's dedup rule is gone | consumer format | undecided | restored after review: spec dedup key copied in the orchestrator (F9) |
| validate.sh:350 | synthesis: the external-premise ledger heading is gone | structural | keep |  |
| validate.sh:352 | synthesis: the approval standard is gone | prose presence | remove |  |
| validate.sh:358 | synthesis: ## Coverage empty or unreadable (read_section) | validator mechanics | keep |  |
| validate.sh:361 | synthesis: spec exclusion gone from ## Coverage | prose presence | remove |  |
| validate.sh:362 | synthesis: not-reported rule gone from ## Coverage | prose presence | remove |  |
| validate.sh:365 | synthesis: missing-block line gone from ## Coverage | prose presence | remove |  |
| validate.sh:366 | synthesis: contradiction line gone from ## Coverage | prose presence | remove |  |
| validate.sh:370 | synthesis: caveat line gone from ## Coverage | prose presence | remove |  |
| validate.sh:372 | synthesis: caveat rule gone (every diff_class) | prose presence | remove |  |
| validate.sh:373 | synthesis: trivial rule gone from ## Coverage | prose presence | remove |  |
| validate.sh:377 | synthesis: trivial rule drops the contract-violation lines | prose presence | remove |  |
| validate.sh:381 | synthesis: ## Coverage no longer shows the coverage line | consumer format | keep | canonical Coverage line |
| validate.sh:382 | synthesis: no-effect rule gone from ## Coverage | prose presence | remove |  |
| validate.sh:393 | synthesis: a coverage line differs from the canonical coverage line | canonical copy | keep |  |
| validate.sh:399 | synthesis: the plan's count is back beside the coverage line | consumer format | keep |  |
| validate.sh:400 | synthesis: ## Output empty or unreadable (read_section) | validator mechanics | keep |  |
| validate.sh:405 | synthesis: Output template has no coverage line | order/position | keep |  |
| validate.sh:407 | synthesis: Output template lost its Spec or Verification line | order/position | keep |  |
| validate.sh:409 | synthesis: Output template orders the header lines wrong | order/position | keep |  |
| validate.sh:416 | synthesis: Output template no longer places the out-of-diff caveat | order/position | keep |  |
| validate.sh:418 | synthesis: Output template no longer places the External premises table | order/position | keep |  |
| validate.sh:420 | synthesis: out-of-diff caveat out of order | order/position | keep |  |
| validate.sh:429 | synthesis: caveat placement no longer follows the Output template | order/position | keep | second copy of the report order |
| validate.sh:434 | synthesis subagent: the coverage inputs are gone | consumer format | undecided | names the block heading and plan key synthesis reads |
| validate.sh:436 | synthesis subagent: the rules inputs are gone | consumer format | undecided | names the plan key and block heading synthesis reads |
| validate.sh:442 | synthesis: the disputed-blocker rule is gone | canonical copy | undecided | restored after review: rule severity.md repeats, 'keep the two identical' (F3) |
| validate.sh:444 | synthesis: the agreement rule is gone | prose presence | remove |  |
| validate.sh:446 | synthesis: the not-verified rule is gone | consumer format | undecided | restored after review: the not-verified label set the orchestrator produces (F4) |
| validate.sh:450 | synthesis: the partly_refuted/no row is gone | consumer format | keep | verdict x defect_stands table synthesis resolves by |
| validate.sh:452 | synthesis: the stands/no row is gone | consumer format | keep | verdict x defect_stands table synthesis resolves by |
| validate.sh:454 | synthesis: the refuted section heading is gone | structural | keep |  |
| validate.sh:456 | synthesis: the citation rule is gone | prose presence | remove |  |
| validate.sh:458 | synthesis: the unchecked marker is gone | consumer format | undecided | report label 'verified, unchecked:' |
| validate.sh:460 | synthesis: the citation definition is gone | consumer format | undecided | restored after review: the verifier's `false` claim value synthesis reads (F12) |
| validate.sh:462 | synthesis: the severity freeze is gone | canonical copy | undecided | restored after review: rule severity.md repeats (F3) |
| validate.sh:464 | synthesis: a numbered step or rule reference | structural | keep |  |
| validate.sh:468 | synthesis: the verification step is gone from Steps | order/position | keep |  |
| validate.sh:470 | synthesis: the conflict-resolution step is gone from Steps | order/position | keep |  |
| validate.sh:472 | synthesis: verification runs before conflict resolution | order/position | keep |  |
| validate.sh:480 | severity.md: shared verdict table predates verification | canonical copy | undecided | copy of synthesis's verdict rule, held by phrase |
| validate.sh:487 | verifier: the cite-or-stand rule is gone | prose presence | remove |  |
| validate.sh:489 | verifier: the no-memory rule is gone | prose presence | remove |  |
| validate.sh:491 | verifier: the one-finding rule is gone | prose presence | remove |  |
| validate.sh:493 | verifier: no 'defect_stands' field | consumer format | keep | output field synthesis reads |
| validate.sh:495 | verifier: the defect_stands rule is gone | consumer format | undecided | restored after review: producer half of the kept resolution table (F12) |
| validate.sh:499 | verifier: the author's-claim rule is gone | prose presence | remove |  |
| validate.sh:501 | verifier: the deleted-file rule is gone | prose presence | remove |  |
| validate.sh:503 | verifier: the harm-not-title rule is gone | prose presence | remove |  |
| validate.sh:511 | security: the missing-layer section is gone | structural | undecided | a section heading, though no consumer reads it |
| validate.sh:513 | security: the not-a-vulnerability section is gone | structural | undecided | a section heading, though no consumer reads it |
| validate.sh:515 | security: the High/Medium question is gone | prose presence | remove |  |
| validate.sh:521 | context-policy: the settling-channel record is gone | prose presence | remove |  |
| validate.sh:523 | context-policy: the local-first channel is gone | prose presence | remove |  |
| validate.sh:560 | category not in the rubric's closed list (Python) | structural | keep | ADR-0006/0007 |
| validate.sh:580 | body declares loads_skill with no rubric | structural | keep |  |
| validate.sh:586 | body names a category its rubric does not list | structural | keep | ADR-0006 |
| validate.sh:595 | premise owners: the premise-verification block is gone | consumer format | keep | block heading synthesis reads |
| validate.sh:597 | premise owners: the unsettled-premise confidence rule is gone | canonical copy | undecided | restored after review: copied verbatim in three rubrics and three bodies (F2) |
| validate.sh:599 | premise owners: no 'settled_by' field | consumer format | keep | field synthesis maps |
| validate.sh:629 | published count: README count (Python) | structural | keep |  |
| validate.sh:631 | published count: README acknowledgements count (Python) | structural | keep |  |
| validate.sh:634 | published count: README roster (Python) | structural | keep |  |
| validate.sh:642 | published count: README diagram arithmetic (Python) | structural | keep |  |
| validate.sh:647 | published count: README diagram node (Python) | structural | keep |  |
| validate.sh:651 | published count: llms.txt count (Python) | structural | keep |  |
| validate.sh:658 | published count: cli/README count (Python) | structural | keep |  |
| validate.sh:660 | published count: cli/README heading (Python) | structural | keep |  |
| validate.sh:663 | published count: cli/README roster (Python) | structural | keep |  |
| validate.sh:671 | published count: cli/package.json description (Python) | structural | keep |  |
| validate.sh:677 | published count: CONTRIBUTING literal (Python) | structural | keep |  |
| validate.sh:681 | published count: CONTRIBUTING add-a-reviewer count (Python) | structural | keep |  |
| validate.sh:694 | published count: CONTRIBUTING reviewer-line scan (Python) | structural | keep |  |
| validate.sh:704 | published count: i18n unreadable (Python) | structural | keep |  |
| validate.sh:709 | published count: i18n roster (Python) | structural | keep |  |
| validate.sh:713 | published count: i18n digit key missing (Python) | structural | keep |  |
| validate.sh:715 | published count: i18n digit key stale (Python) | structural | keep |  |
| validate.sh:724 | published count: i18n word key missing (Python) | structural | keep |  |
| validate.sh:726 | published count: i18n no numeral word (Python) | structural | keep |  |
| validate.sh:728 | published count: i18n word key stale (Python) | structural | keep |  |
| validate.sh:739 | manifest.json not found | structural | keep |  |
| validate.sh:742 | manifest.json invalid JSON | structural | keep |  |
| validate.sh:749 | orphan skill | structural | keep |  |
| validate.sh:759 | declared skill absent | structural | keep |  |
| validate.sh:772 | orphan agent | structural | keep |  |
| validate.sh:778 | declared agent absent | structural | keep |  |
| validate.sh:785 | agent missing loads_skill | structural | keep |  |
| validate.sh:787 | agent references missing skill | structural | keep |  |
| validate.sh:791 | skills: field must match loads_skill | structural | keep |  |
| validate.sh:809 | pack manifest invalid JSON | structural | keep |  |
| validate.sh:811 | pack manifest missing reviewers | structural | keep |  |
| validate.sh:815 | pack manifest missing version | structural | keep |  |
| validate.sh:820 | pack lists reviewer with no core skill | structural | keep |  |
| validate.sh:823 | pack reviewer file missing | structural | keep |  |
| validate.sh:828 | pack file missing section | structural | keep |  |
| validate.sh:864 | SKILL.md outside core/skills/ | structural | keep |  |
| validate.sh:873 | agent frontmatter outside core/agents/ | structural | keep |  |
| validate.sh:922 | version alignment: version file unreadable (Python) | structural | keep |  |
| validate.sh:936 | version alignment: marketplace version (Python) | structural | keep |  |
| validate.sh:939 | version alignment: marketplace plugins[i] version (Python) | structural | keep |  |
| validate.sh:943 | version alignment: plugin manifest version (Python) | structural | keep |  |
| validate.sh:951 | version alignment: lockfile version (Python) | structural | keep |  |
| validate.sh:976 | category-root list not found (Python) | structural | keep |  |
| validate.sh:985 | category roots disagree with manifest.json (Python) | structural | keep |  |
| validate.sh:1005 | a sourced check file could not be sourced | validator mechanics | keep |  |
| validate-repo-rules.sh:10 | triage: rules no longer read from the merge base | prose presence | remove |  |
| validate-repo-rules.sh:12 | triage: the rule-owner dispatch is gone | prose presence | remove |  |
| validate-repo-rules.sh:14 | triage: the rules cap no longer counts what it drops | consumer format | undecided | names the `rules_dropped` plan key synthesis prints |
| validate-repo-rules.sh:17 | triage: the rule-as-data line is gone | prose presence | remove |  |
| validate-repo-rules.sh:19 | triage: the rule-as-data line no longer forbids acting on it | prose presence | remove |  |
| validate-repo-rules.sh:22 | triage: the step that reads the rules no longer reads the merge base | prose presence | remove |  |
| validate-repo-rules.sh:24 | triage: one row per rule is gone | prose presence | remove |  |
| validate-repo-rules.sh:26 | triage: a target this change adds no longer counts as changed | prose presence | remove |  |
| validate-repo-rules.sh:28 | triage: a new {name} instance without its counterpart would be dropped | prose presence | remove |  |
| validate-repo-rules.sh:30 | triage: the binding state order is gone | prose presence | remove |  |
| validate-repo-rules.sh:32 | triage: no 'repository_rules' key in the plan format | consumer format | keep | plan key |
| validate-repo-rules.sh:38 | orchestrator: the owners' Repository rules section is missing | structural | keep | prompt section owners read by name |
| validate-repo-rules.sh:40 | orchestrator: no longer names the marker bounds | canonical copy | keep | ties the prompt to the marker-bounded copy |
| validate-repo-rules.sh:44 | orchestrator: handling text markers are missing | canonical copy | keep |  |
| validate-repo-rules.sh:49 | orchestrator: handling text differs from the reviewer bodies | canonical copy | keep |  |
| validate-repo-rules.sh:56 | orchestrator: text follows the closing handling marker | canonical copy | keep |  |
| validate-repo-rules.sh:60 | orchestrator: text precedes the opening handling marker | canonical copy | keep |  |
| validate-repo-rules.sh:63 | orchestrator: verifier no longer told to read rules at the merge base | prose presence | undecided | only guard of the `### Rules file` prompt section the verifier reads by name |
| validate-repo-rules.sh:64 | orchestrator: Repository rules block differs (has_rules_block) | canonical copy | keep |  |
| validate-repo-rules.sh:69 | verifier: no longer reads rules at the merge base | canonical copy | undecided | restored after review: rule the orchestrator's Rules file 'reminder' restates (F5) |
| validate-repo-rules.sh:74 | output-schema.md: the rules Medium cap is gone | prose presence | remove |  |
| validate-repo-rules.sh:80 | synthesis: ## Repository rules empty or unreadable (read_section) | validator mechanics | keep |  |
| validate-repo-rules.sh:83 | synthesis: the rules omit rule is gone | consumer format | undecided | restored after review: prints for the plan's repository_rules absence (F6) |
| validate-repo-rules.sh:84 | synthesis: the rules not-reported rule is gone | prose presence | remove |  |
| validate-repo-rules.sh:85 | synthesis: the rules dropped line is gone | consumer format | undecided | restored after review: prints the plan's `rules_dropped` (F6) |
| validate-repo-rules.sh:86 | synthesis: the rules-file-changed line is gone | consumer format | undecided | restored after review: prints `file_changed: changed` (F6) |
| validate-repo-rules.sh:87 | synthesis: the rules-file-added line is gone | consumer format | undecided | restored after review: prints `file_changed: added` (F6) |
| validate-repo-rules.sh:89 | synthesis: the no-target row no longer covers a target this change adds | prose presence | remove |  |
| validate-repo-rules.sh:91 | synthesis: Dedup no longer drops the rules citation | prose presence | remove |  |
| validate-repo-rules.sh:92 | synthesis: the merged-severity rule is gone | prose presence | remove |  |
| validate-repo-rules.sh:97 | synthesis: the lines beneath an omitted rules table no longer print | consumer format | undecided | restored after review: prints when `rows` is empty or absent (F6) |
| validate-repo-rules.sh:100 | synthesis: the rules-uncommitted line is gone or narrowed | consumer format | undecided | restored after review: prints the plan's `uncommitted` (F6) |
| validate-repo-rules.sh:109 | synthesis: the rules cap no longer runs before verification | order/position | keep |  |
| validate-repo-rules.sh:114 | synthesis: the rules out-of-diff exclusion is gone | prose presence | remove |  |
| validate-repo-rules.sh:121 | ai-antipatterns: no longer names the category a rule violation files under | structural | keep | ADR-0007 closed list covers the flag |
| validate-repo-rules.sh:128 | orchestrator: Prep no longer stops when no merge base resolves | canonical copy | undecided | restored after review: base rule restated in triage, triage subagent and review.sh (F7) |
| validate-repo-rules.sh:130 | orchestrator: the Rules file section no longer splits a finding in rules.md | canonical copy | undecided | restored after review: orchestrator half of the verifier rule (F5) |
| validate-repo-rules.sh:132 | orchestrator: the verifier's Change description is no longer last | order/position | undecided | only guard of the `### Change description` prompt section; the 'last' is a stated position, not a measured one |
| validate-repo-rules.sh:136 | triage: step 3 no longer stops when no merge base resolves | canonical copy | undecided | restored after review: base rule copy (F7) |
| validate-repo-rules.sh:138 | triage: an edit to rules.md no longer dispatches security | prose presence | remove |  |
| validate-repo-rules.sh:142 | triage: a rules edit no longer dispatches the base copy's owner | prose presence | remove |  |
| validate-repo-rules.sh:145 | triage: HEAD's rules.md is no longer read with git show | prose presence | remove |  |
| validate-repo-rules.sh:150 | verifier: no longer splits a finding located in rules.md | canonical copy | undecided | restored after review: rule the orchestrator's Rules file reminder restates (F5) |
| validate-repo-rules.sh:154 | synthesis: a finding located in rules.md no longer counts as citing it | prose presence | remove |  |
| validate-repo-rules.sh:159 | synthesis subagent: no longer names the External premises inputs | consumer format | undecided | names the plan keys and block heading synthesis reads |
| validate-repo-rules.sh:169 | triage: staged and unstaged rules edits no longer listed as uncommitted | prose presence | remove |  |
| validate-repo-rules.sh:172 | triage: an untracked rules file is no longer listed | prose presence | remove |  |
| validate-repo-rules.sh:175 | triage: uncommitted no longer follows either read | prose presence | remove |  |
| validate-repo-rules.sh:177 | triage: an uncommitted rules edit may now be applied | prose presence | remove |  |
| validate-repo-rules.sh:179 | triage: an uncommitted rules edit may now change rows or dispatch | prose presence | remove |  |
| validate-repo-rules.sh:183 | triage: a rules file only in the working tree emits nothing again | prose presence | remove |  |
| validate-repo-rules.sh:186 | triage: plan no longer carries uncommitted as an optional field | consumer format | keep | plan field; v1.0 plans without it stay valid |
| validate-repo-rules.sh:191 | triage: plan schema may omit repository_rules (comment) | prose presence | remove |  |
| validate-repo-rules.sh:193 | triage: the plan's source comment no longer covers a working-tree-only file | consumer format | undecided | only guard of the plan's `source:` field line |
| validate-stack-signals.sh:10 | PACK_DATA_LINE is empty or unset | validator mechanics | keep |  |
| validate-stack-signals.sh:15 | triage: stacks no longer detected from the merge base | prose presence | remove |  |
| validate-stack-signals.sh:18 | triage: ls-tree step no longer lists the merge base | prose presence | remove |  |
| validate-stack-signals.sh:23 | triage: committed pack comparison no longer merge base to HEAD | prose presence | remove |  |
| validate-stack-signals.sh:25 | triage: added state no longer compares HEAD | prose presence | remove |  |
| validate-stack-signals.sh:27 | triage: removed and changed states are gone | prose presence | remove |  |
| validate-stack-signals.sh:30 | triage: staged and unstaged pack edits no longer listed | prose presence | remove |  |
| validate-stack-signals.sh:32 | triage: untracked pack files no longer listed | prose presence | remove |  |
| validate-stack-signals.sh:34 | triage: uncommitted state gone or narrowed | prose presence | remove |  |
| validate-stack-signals.sh:37 | triage: stack_signals no longer omitted without packs | prose presence | remove |  |
| validate-stack-signals.sh:39 | triage: bar on reading a head pack is gone | prose presence | remove |  |
| validate-stack-signals.sh:42 | triage: committed pack edit no longer compels a dispatch | prose presence | remove |  |
| validate-stack-signals.sh:44 | triage: pack edit no longer dispatches its reviewer | prose presence | remove |  |
| validate-stack-signals.sh:46 | triage: compelled reviewers no longer handed the pack files | prose presence | remove |  |
| validate-stack-signals.sh:49 | triage: base's later pack changes no longer listed | prose presence | remove |  |
| validate-stack-signals.sh:51 | triage: the behind state is gone | prose presence | remove |  |
| validate-stack-signals.sh:56 | triage: Stack signals section no longer reads packs at the merge base | prose presence | remove |  |
| validate-stack-signals.sh:59 | triage: the base is no longer the branch ref | canonical copy | undecided | restored after review: base rule copy (F7) |
| validate-stack-signals.sh:53 | triage: the plan's change states no longer list every state | consumer format | keep | closed enum synthesis maps |
| validate-stack-signals.sh:61 | triage: no 'stack_signals' key in the plan format | consumer format | keep | plan key |
| validate-stack-signals.sh:67 | triage/orchestrator: stacks globbed in the working tree again | prose presence | remove |  |
| validate-stack-signals.sh:73 | orchestrator: base no longer resolved as a branch ref | canonical copy | undecided | restored after review: base rule review.sh implements (F7) |
| validate-stack-signals.sh:75 | orchestrator: named base no longer resolved as a branch | canonical copy | undecided | restored after review: base rule review.sh implements (F7) |
| validate-stack-signals.sh:77 | orchestrator: full ref no longer looked up exactly | canonical copy | undecided | restored after review: base rule review.sh implements (F7) |
| validate-stack-signals.sh:79 | orchestrator: sha no longer required to be full | canonical copy | undecided | restored after review: base rule review.sh implements (F7) |
| validate-stack-signals.sh:82 | orchestrator: no longer runs the reviewers a pack edit compels | prose presence | remove |  |
| validate-stack-signals.sh:85 | orchestrator: signals no longer read with git show | prose presence | remove |  |
| validate-stack-signals.sh:87 | orchestrator: fan-out no longer bars the working tree | prose presence | remove |  |
| validate-stack-signals.sh:94 | orchestrator: Stack signals no longer sent when files include a pack | prose presence | remove |  |
| validate-stack-signals.sh:97 | orchestrator: inline review no longer applies the base's signals | prose presence | remove |  |
| validate-stack-signals.sh:92 | orchestrator: Stack signals section no longer carries the pack line verbatim | canonical copy | keep |  |
| validate-stack-signals.sh:100 | orchestrator: verifier no longer told to read a cited pack at the merge base | prose presence | undecided | only guard of the `### Pack files` prompt section the verifier reads by name |
| validate-stack-signals.sh:102 | orchestrator: verification no longer exempts the finding's own pack file | canonical copy | undecided | restored after review: orchestrator half of the verifier pack rule (F5) |
| validate-stack-signals.sh:109 | orchestrator: Stack signals no longer before the changed files | order/position | keep |  |
| validate-stack-signals.sh:116 | orchestrator: changed files no longer the last prompt section | order/position | keep |  |
| validate-stack-signals.sh:120 | orchestrator: no-reviewer path no longer prints rules and pack output | prose presence | remove |  |
| validate-stack-signals.sh:122 | orchestrator: no-reviewer path no longer says when to print | prose presence | remove |  |
| validate-stack-signals.sh:128 | verifier: no longer reads a cited pack at the merge base | canonical copy | undecided | restored after review: rule the orchestrator's Pack files reminder restates (F5) |
| validate-stack-signals.sh:130 | verifier: no longer exempts the finding's own pack file | canonical copy | undecided | restored after review: rule the orchestrator's Pack files reminder restates (F5) |
| validate-stack-signals.sh:134 | synthesis: ## Stack signals empty or unreadable (read_section) | validator mechanics | keep |  |
| validate-stack-signals.sh:137 | synthesis: the pack-added line is gone | consumer format | undecided | restored after review: line the kept state mapping points at by position (F1) |
| validate-stack-signals.sh:139 | synthesis: the pack-removed line is gone | consumer format | undecided | restored after review: line the state mapping points at (F1) |
| validate-stack-signals.sh:141 | synthesis: the pack-changed line is gone | consumer format | undecided | restored after review: line the state mapping points at (F1) |
| validate-stack-signals.sh:143 | synthesis: the pack-uncommitted line is gone | consumer format | undecided | restored after review: line the state mapping points at (F1) |
| validate-stack-signals.sh:145 | synthesis: the pack-behind line is gone | consumer format | undecided | restored after review: line the state mapping points at (F1) |
| validate-stack-signals.sh:147 | synthesis: the state-to-line mapping is gone | consumer format | undecided | consumer side of the plan's `change` enum |
| validate-stack-signals.sh:150 | synthesis: stack lines no longer print on every diff_class | prose presence | remove |  |
| validate-stack-signals.sh:151 | synthesis: stack lines may now change the verdict | prose presence | remove |  |
| validate-stack-signals.sh:154 | synthesis: the stack-signals omit rule is gone | prose presence | remove |  |
| validate-stack-signals.sh:159 | synthesis: the pack out-of-diff exclusion is gone | prose presence | remove |  |
| validate-stack-signals.sh:164 | synthesis subagent: the stack_signals input is gone | consumer format | undecided | names the plan key synthesis reads |
| validate-stack-signals.sh:174 | triage subagent: base no longer resolved with exact ref lookups | canonical copy | undecided | restored after review: Prep's base rule restated in the triage subagent (F7) |
| validate-stack-signals.sh:176 | triage subagent: named base no longer refuses a tag | canonical copy | undecided | restored after review: base rule copy (F7) |
| validate-stack-signals.sh:179 | triage subagent: caller's base no longer a full sha | canonical copy | undecided | restored after review: base rule copy (F7) |
| validate-stack-signals.sh:181 | triage subagent: named base no longer an exact branch ref | canonical copy | undecided | restored after review: base rule copy (F7) |
| validate-stack-signals.sh:183 | triage subagent: full ref no longer looked up exactly | canonical copy | undecided | restored after review: base rule copy (F7) |
| validate-stack-signals.sh:186 | triage subagent: no longer stops when no merge base resolves | canonical copy | undecided | restored after review: base rule copy (F7) |
| validate-stack-signals.sh:188 | triage subagent: body names a configured base again | canonical copy | undecided | restored after review: base rule copy (F7) |
| validate-dispatch.sh:18 | orchestrator: the dispatch line is gone | canonical copy | keep | canonical dispatch clause |
| validate-dispatch.sh:20 | orchestrator: dispatch no longer starts every agent in one step | canonical copy | keep | canonical dispatch clause |
| validate-dispatch.sh:22 | orchestrator: dispatch line asks for background dispatch | canonical copy | keep | canonical dispatch clause |
