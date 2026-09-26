"""Compare a reviewer's declared `## Files examined` block against its transcript.

Usage: python3 analyze.py <label> <transcript.jsonl>
A file counts as "in view" when a tool call Read it, or a Bash command named it,
or a Bash command ran a whole-commit diff/show/log -p whose result was not truncated.
"""
import json, re, sys, os

label, path = sys.argv[1], sys.argv[2]
here = os.path.dirname(os.path.abspath(__file__))
changed = [l.strip() for l in open(os.path.join(here, "changed.txt")) if l.strip()]

calls, results, final_text = {}, {}, ""
for line in open(path):
    try:
        e = json.loads(line)
    except ValueError:
        continue
    msg = e.get("message") or {}
    content = msg.get("content")
    if not isinstance(content, list):
        continue
    for c in content:
        if c.get("type") == "tool_use":
            calls[c["id"]] = (c["name"], c.get("input", {}))
            if c["name"] == "SubagentHandback":
                final_text = c.get("input", {}).get("message", "")
        elif c.get("type") == "tool_result":
            body = c.get("content")
            if isinstance(body, list):
                body = "".join(x.get("text", "") for x in body if isinstance(x, dict))
            results[c["tool_use_id"]] = body or ""
        elif c.get("type") == "text" and msg.get("role") == "assistant" and not final_text:
            final_text = c["text"]

in_view, whole, trims = set(), [], []
for cid, (name, inp) in calls.items():
    res = results.get(cid, "")
    if name == "Read":
        fp = inp.get("file_path", "")
        for f in changed:
            if fp.endswith("/" + f):
                in_view.add(f)
    elif name == "Bash":
        cmd = inp.get("command", "")
        # Path boundaries, not substrings: `README.md` must not match `studies/.../README.md`.
        named = [f for f in changed if re.search(r"(?<![\w./-])" + re.escape(f) + r"(?![\w/-])", cmd)]
        in_view.update(named)
        # any file whose diff header or full path appears in what the command returned
        for f in changed:
            if f"diff --git a/{f} b/{f}" in res:
                in_view.add(f)
        # rtk's compact diff: a stat block, then "Changes:" and one bare path line per file
        if "Changes:" in res:
            heads = {l.strip() for l in res.split("Changes:", 1)[1].splitlines()}
            in_view.update(f for f in changed if f in heads)
        for l in res.splitlines():
            if re.search(r"(lines? (truncated|omitted|hidden)|more lines|\[see remaining)", l, re.I):
                trims.append((name, l.strip()[:120]))
        if not named and re.search(r"\b(diff|show|log -p)\b", cmd) and "8649dad" in cmd:
            truncated = ("truncated" in res.lower()) or ("Output too large" in res) or ("persisted" in res.lower())
            whole.append((cmd[:120], len(res), truncated))
            if not truncated and "--stat" not in cmd and "--name-only" not in cmd:
                for f in changed:
                    if f"b/{f}" in res:
                        in_view.add(f)

m = re.search(r"## Files examined(.*)", final_text, re.S)
block = m.group(1) if m else ""
ex_m = re.search(r"examined:\s*\[(.*?)\]", block, re.S)
examined = {x.strip() for x in ex_m.group(1).split(",")} if ex_m else set()
examined.discard("")
not_ex = set(re.findall(r"-\s*file:\s*(\S+)", block))
findings = set(re.findall(r"^\s*file:\s*(\S+)", final_text.split("## Files examined")[0], re.M))

print(f"== {label}")
print(f"block present: {bool(m)}")
print(f"tool calls: {len(calls)}")
print(f"declared examined: {len(examined)}  declared not_examined: {len(not_ex)}")
print(f"not_examined outside studies/: {sorted(f for f in not_ex if not f.startswith('studies/'))}")
omitted = [f for f in changed if f not in examined and f not in not_ex]
print(f"omitted from both lists: {len(omitted)} {omitted[:10]}")
both = examined & not_ex
print(f"in both lists: {sorted(both)}")
unknown = (examined | not_ex) - set(changed)
print(f"listed but not in changed list: {sorted(unknown)}")
over = sorted(f for f in examined if f not in in_view)
print(f"OVERCLAIM (declared examined, never in view): {len(over)} {over}")
under = sorted(f for f in not_ex if f in in_view)
print(f"underclaim (declared not examined, but was in view): {len(under)} {under}")
print(f"finding files: {sorted(findings)}; contradictions: {sorted(findings & not_ex)}")
print(f"whole-commit diff commands: {whole}")
print(f"trim markers in tool output: {trims}")
