import { describe, it, expect } from "vitest";
import { parseAgentMd, mdToCodexToml } from "../src/lib/agents.js";

const MD = `---
name: security-reviewer
description: "Security reviewer subagent."
loads_skill: security
skills: [security]
---

# Security Reviewer (subagent)

You are a review-pro subagent. Apply your core skill.
`;

describe("agents", () => {
  it("parses canonical agent md", () => {
    const a = parseAgentMd(MD);
    expect(a.name).toBe("security-reviewer");
    expect(a.description).toBe("Security reviewer subagent.");
    expect(a.loads_skill).toBe("security");
    expect(a.body).toContain("review-pro subagent");
  });

  it("transforms to codex toml without skills.config", () => {
    const a = parseAgentMd(MD);
    const toml = mdToCodexToml(a);
    expect(toml).toContain('name = "security-reviewer"');
    expect(toml).toContain('sandbox_mode = "read-only"');
    expect(toml).toContain('developer_instructions = """');
    expect(toml).not.toContain('[[skills.config]]');
    expect(toml).not.toContain('path =');
  });

  it("throws on missing frontmatter", () => {
    expect(() => parseAgentMd("no frontmatter")).toThrow(/frontmatter/);
  });
});
