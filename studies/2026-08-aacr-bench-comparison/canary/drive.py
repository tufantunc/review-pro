"""Canary driver: build A1's exact argv from the fork's own helpers, plus Amendment 2's flags."""
import json, os, subprocess, sys
sys.path.insert(0, os.path.expanduser("~/Desktop/Projects/Personal/aacr-bench/evaluation"))
from pathlib import Path
import config
from reviewers import claude as c
W = Path(sys.argv[1]); label = sys.argv[2]; repo = Path(sys.argv[3]); prompt = sys.argv[4]
res = W / "results" / label; res.mkdir(parents=True, exist_ok=True)
settings = c._write_temp_settings(c.build_hook_settings(res, label))
argv = ["claude", "-p", prompt, "--add-dir", str(repo), "--permission-mode", "acceptEdits",
        "--output-format", "stream-json", "--verbose",   # adapter uses json; stream-json here to read the init event
        "--mcp-config", json.dumps(c.build_mcp_config(res, label)), "--allowed-tools", config.MCP_REPORT_TOOL,
        "--append-system-prompt", c.build_findings_system_prompt(), "--settings", settings,
        # Amendment 2 flags, both arms:
        "--model", "claude-opus-5-5", "--effort", "high", "--setting-sources", "project,local", "--strict-mcp-config"]
env = os.environ.copy(); env["ANTHROPIC_MODEL"] = "claude-opus-5-5"; env["CLAUDE_CODE_MAX_RETRIES"] = "10"
for k in ("ANTHROPIC_API_KEY", "CLAUDE_CODE_OAUTH_TOKEN", "ANTHROPIC_BASE_URL", "ANTHROPIC_AUTH_TOKEN", "CLAUDE_CONFIG_DIR"):
    env.pop(k, None)
p = subprocess.run(argv, cwd=repo, env=env, capture_output=True, text=True, timeout=1800)
(res / "stream.jsonl").write_text(p.stdout); (res / "stderr.txt").write_text(p.stderr)
ev = [json.loads(l) for l in p.stdout.splitlines() if l.strip()]
init = next(e for e in ev if e.get("type") == "system" and e.get("subtype") == "init")
result = [e for e in ev if e.get("type") == "result"][-1]
rp = [a for a in init.get("agents", [])]; sk = init.get("skills", [])
out = {"label": label, "exit": p.returncode, "agents": rp, "skills": sk, "plugins": [x["name"] for x in init.get("plugins", [])],
       "mcp_servers": init.get("mcp_servers"), "permission_denials": result.get("permission_denials"),
       "result": result.get("result", "")[:3000], "mcp_partial": sorted(os.listdir(res))}
(res / "summary.json").write_text(json.dumps(out, indent=1))
print(json.dumps({k: out[k] for k in ("label", "exit", "agents", "skills", "plugins", "mcp_servers")}, indent=None))
print("permission_denials:", json.dumps(out["permission_denials"])[:800])
print("RESULT:", out["result"][:1500])
