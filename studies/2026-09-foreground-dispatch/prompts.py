"""The prompts this study sends, built from the clones so every run is reproducible.

Usage: python3 prompts.py <work dir> review <case>     /review-pro, with the PR body as the spec argument when there is one
       python3 prompts.py <work dir> triage <case>     /review-pro-triage alone, for the fidelity check
       python3 prompts.py <work dir> j07 <a|b>         the J07 owner prompt: a = R3 as written in rules.md, b = the spike's C3 sentence

The J07 prompt is the orchestrator's owner prompt for #62 (core/skills/review-pro/SKILL.md step 3.2
at the product commit): changed file contents, the Files examined reminder, and the R3 row followed
by the handling text between the repository-rules-handling markers, verbatim. A thin main session
forwards it to the ai-antipatterns-reviewer subagent unchanged.
"""
import os, re, subprocess, sys

GIT = "/opt/homebrew/bin/git" if os.path.exists("/opt/homebrew/bin/git") else "/usr/bin/git"
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
PRODUCT = "bccb367"
C3_DRAFT = "A version change in `cli/package.json` must be mirrored in the lockfile and the four plugin manifests."


def g(repo, *a):
    return subprocess.run([GIT, "-C", repo, *a], capture_output=True, text=True, check=True).stdout


def review(work, case):
    body = os.path.join(work, case, "pr-body.md")
    if os.path.exists(body) and open(body).read().strip():
        return f"/review-pro {body}"
    return "/review-pro"


def triage(work, case):
    return "/review-pro-triage Base branch: main. Return only the dispatch plan (the YAML block) and the one-line summary."


def j07(work, variant):
    repo = os.path.join(work, "t62", "repo")
    orch = g(ROOT, "show", f"{PRODUCT}:core/skills/review-pro/SKILL.md")
    handling = orch.split("<!-- repository-rules-handling -->\n", 1)[1].split("\n<!-- /repository-rules-handling -->", 1)[0]
    rules = g(repo, "show", "main:.review-pro/rules.md")
    line = next(i for i, l in enumerate(rules.split("\n"), 1) if l.startswith("## R3:"))
    text = re.search(r"^## R3:.*?^- rule: (.*?)$", rules, re.M | re.S).group(1) if variant == "a" else C3_DRAFT
    files = [f for f in g(repo, "diff", "--name-only", "main...HEAD").split("\n") if f]
    parts = ["### Changed file contents"]
    for f in files:
        status = g(repo, "diff", "--name-status", "main...HEAD", "--", f).split("\t")[0]
        if status == "D" or f.endswith("package-lock.json"):
            parts.append(f"#### {f} ({'deleted' if status == 'D' else 'diff only; lockfile'})\n```diff\n{g(repo, 'diff', 'main...HEAD', '--', f)}```")
        else:
            parts.append(f"#### {f}\n```\n{g(repo, 'show', 'HEAD:' + f)}```")
    parts.append("### Files examined\nEnd with your `## Files examined` block: `examined: [...]`, then `not_examined:` entries with `file` "
                 "and `reason`, accounting for each file in `### Changed file contents` exactly once. A file counts as examined only "
                 "if you read its diff or contents; a complete-looking list that overstates what you read is wrong.")
    parts.append("### Repository rules\n"
                 f"- R3 (.review-pro/rules.md:{line}): matched cli/package.json; missing .cursor-plugin/plugin.json; \"{text}\"\n\n" + handling)
    task = "\n\n".join(parts)
    return ("Invoke the ai-antipatterns-reviewer agent (Agent tool, subagent_type ai-antipatterns-reviewer) with the task prompt "
            "between the markers below, passed verbatim and in full, without the markers. Then reply with its answer verbatim and "
            "nothing else.\n\n<<<TASK\n" + task + "\nTASK>>>")


if __name__ == "__main__":
    work, kind, arg = sys.argv[1:4]
    sys.stdout.write({"review": review, "triage": triage, "j07": j07}[kind](work, arg))
