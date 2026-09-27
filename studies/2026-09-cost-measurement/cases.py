"""Build the throwaway clones this study reviews, one per case, reproducibly.

Usage: python3 cases.py <work dir> <case> [<case> ...]     (or `all`)

Each clone: a local clone of this repository, `main` = the case's base (plus a commit adding this
repository's .review-pro/rules.md when the base has none, plus any base edit the case names),
`pr-<case>` = the head (the PR's commit cherry-picked, or the case's edits). review-pro itself is
installed at project scope from the product commit PRODUCT: core/skills -> .claude/skills,
core/agents -> .claude/agents, core/shared -> .claude/shared, mirroring what the CLI copies to
~/.claude for Claude Code. Commits use a fixed identity and date, so every sha is reproducible.
"""
import os, shutil, subprocess, sys

GIT = "/opt/homebrew/bin/git" if os.path.exists("/opt/homebrew/bin/git") else "/usr/bin/git"
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
PRODUCT = "bccb367"  # main after #80: the review-pro under measurement
ENV = dict(os.environ, GIT_AUTHOR_NAME="study", GIT_AUTHOR_EMAIL="study@example.invalid",
           GIT_COMMITTER_NAME="study", GIT_COMMITTER_EMAIL="study@example.invalid",
           GIT_AUTHOR_DATE="2026-09-27T12:00:00Z", GIT_COMMITTER_DATE="2026-09-27T12:00:00Z")

PR = {  # merged PR -> squash commit on main
    "39": "39", "53": "53", "62": "62", "71": "71", "77": "77", "78": "78",
}

# case: (kind, base, head edits)
# natural: base = PR commit^1, head = the PR commit cherry-picked
# variant: base and head are built by the named function
CASES = {
    "c77": ("natural", "77"), "c39": ("natural", "39"), "c53": ("natural", "53"), "c78": ("natural", "78"),
    "t62": ("natural", "62"), "t71": ("natural", "71"),
    "v71-nomanifest": ("variant", "v71_nomanifest"), "v-newpack": ("variant", "v_newpack"),
    "v-newpack-manifest": ("variant", "v_newpack_manifest"), "v-notarget": ("variant", "v_notarget"),
    "v-schema": ("variant", "v_schema"), "v-docsrc": ("variant", "v_docsrc"),
}


def g(repo, *args, check=True):
    return subprocess.run([GIT, "-C", repo, *args], capture_output=True, text=True, env=ENV, check=check).stdout


def merge_commit(num):
    out = subprocess.run(["gh", "pr", "view", num, "--json", "mergeCommit", "-q", ".mergeCommit.oid"],
                         capture_output=True, text=True, cwd=ROOT, check=True).stdout.strip()
    return out


def fresh(dest, base):
    if os.path.exists(dest):
        shutil.rmtree(dest)
    subprocess.run([GIT, "clone", "-q", ROOT, dest], check=True, env=ENV)
    g(dest, "checkout", "-q", "-B", "main", base)
    g(dest, "remote", "remove", "origin")  # no route to GitHub: gh falls through, nothing is pushed
    if g(dest, "ls-tree", "--name-only", "HEAD", ".review-pro/rules.md").strip() == "":
        os.makedirs(os.path.join(dest, ".review-pro"), exist_ok=True)
        with open(os.path.join(dest, ".review-pro/rules.md"), "w") as fh:
            fh.write(g(ROOT, "show", f"{PRODUCT}:.review-pro/rules.md"))
        g(dest, "add", ".review-pro/rules.md")
        g(dest, "commit", "-q", "-m", "study: this repository's rules at the base")


def install(dest):
    for sub in ("skills", "agents", "shared"):
        tgt = os.path.join(dest, ".claude", sub)
        os.makedirs(tgt, exist_ok=True)
        tar = subprocess.run([GIT, "-C", ROOT, "archive", PRODUCT, f"core/{sub}"], capture_output=True, check=True).stdout
        subprocess.run(["tar", "-x", "-C", tgt, "--strip-components=2"], input=tar, check=True)
    with open(os.path.join(dest, ".git/info/exclude"), "a") as fh:
        fh.write(".claude/\n")


def edit(dest, path, fn):
    p = os.path.join(dest, path)
    s = open(p).read()
    s2 = fn(s)
    assert s2 != s, path
    open(p, "w").write(s2)
    g(dest, "add", path)


def v71_nomanifest(dest):
    c = merge_commit("71")
    fresh(dest, c + "^1")
    g(dest, "checkout", "-q", "-b", "pr-v71-nomanifest")
    g(dest, "cherry-pick", c)
    # drop one pack's manifest bump: R2 binding pack=go becomes judge, the other ten stay alongside
    g(dest, "checkout", "HEAD~1", "--", "stacks/go/manifest.json")
    g(dest, "commit", "-q", "--amend", "--no-edit")


def v_newpack(dest, with_manifest=False):
    fresh(dest, PRODUCT)
    g(dest, "checkout", "-q", "-b", "pr-" + ("v-newpack-manifest" if with_manifest else "v-newpack"))
    os.makedirs(os.path.join(dest, "stacks/newpack"), exist_ok=True)
    with open(os.path.join(dest, "stacks/newpack/security.md"), "w") as fh:
        fh.write("# newpack: security signals\n\n- Flag a handler that reads a request body without a size limit.\n")
    g(dest, "add", "stacks/newpack/security.md")
    if with_manifest:
        with open(os.path.join(dest, "stacks/newpack/manifest.json"), "w") as fh:
            fh.write('{\n  "name": "newpack",\n  "version": "0.1.0",\n  "description": "A study pack."\n}\n')
        g(dest, "add", "stacks/newpack/manifest.json")
    g(dest, "commit", "-q", "-m", "feat(stacks): add newpack")


def v_newpack_manifest(dest):
    v_newpack(dest, with_manifest=True)


def v_notarget(dest):
    fresh(dest, PRODUCT)
    g(dest, "rm", "-q", "docs/llms.txt")
    g(dest, "commit", "-q", "-m", "study: a base without docs/llms.txt")
    g(dest, "checkout", "-q", "-b", "pr-v-notarget")
    edit(dest, "core/skills/security/SKILL.md", lambda s: s.rstrip("\n") + "\n\nA study line: name the header a finding rests on.\n")
    g(dest, "commit", "-q", "-m", "docs(security): name the header a finding rests on")


def v_schema(dest):
    fresh(dest, PRODUCT)
    g(dest, "checkout", "-q", "-b", "pr-v-schema")
    edit(dest, "core/shared/output-schema.md", lambda s: s.rstrip("\n") + "\n\nA study rule: `title` stays under 80 characters.\n")
    g(dest, "commit", "-q", "-m", "docs(schema): cap the title length")


def v_docsrc(dest):
    fresh(dest, PRODUCT)
    g(dest, "checkout", "-q", "-b", "pr-v-docsrc")
    edit(dest, "docs-src/i18n/tr.json", lambda s: s.replace("review-pro", "review-pro ", 1))
    g(dest, "commit", "-q", "-m", "docs(site): adjust a Turkish string")


def build(work, case):
    kind, arg = CASES[case]
    dest = os.path.join(work, case, "repo")
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    if kind == "natural":
        c = merge_commit(arg)
        fresh(dest, c + "^1")
        g(dest, "checkout", "-q", "-b", f"pr-{case}")
        g(dest, "cherry-pick", c)
        body = subprocess.run(["gh", "pr", "view", arg, "--json", "body", "-q", ".body"],
                              capture_output=True, text=True, cwd=ROOT, check=True).stdout
        with open(os.path.join(work, case, "pr-body.md"), "w") as fh:
            fh.write(body)
    else:
        globals()[arg](dest)
    install(dest)
    base = g(dest, "rev-parse", "main").strip()
    head = g(dest, "rev-parse", "HEAD").strip()
    n = len([l for l in g(dest, "diff", "--name-only", "main...HEAD").split("\n") if l])
    print(f"{case}: base {base[:10]} head {head[:10]} files {n}")


if __name__ == "__main__":
    work = sys.argv[1]
    names = list(CASES) if sys.argv[2:] == ["all"] else sys.argv[2:]
    for c in names:
        build(work, c)
