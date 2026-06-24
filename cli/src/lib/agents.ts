import path from "node:path";

export interface CanonicalAgent {
  name: string;
  description: string;
  loads_skill: string;
  body: string;
}

function unquote(v: string): string {
  return v.replace(/^"/, "").replace(/"$/, "");
}

export function parseAgentMd(content: string): CanonicalAgent {
  const lines = content.split("\n");
  if (lines[0].trim() !== "---") throw new Error("agent: missing frontmatter");
  const fm: Record<string, string> = {};
  let i = 1;
  while (i < lines.length && lines[i].trim() !== "---") {
    const m = lines[i].match(/^([a-zA-Z_]+):\s*(.*)$/);
    if (m) fm[m[1]] = m[2];
    i++;
  }
  if (i >= lines.length) throw new Error("agent: unterminated frontmatter");
  const body = lines.slice(i + 1).join("\n").trim();
  if (!fm.name) throw new Error("agent: missing name");
  if (!fm.loads_skill) throw new Error("agent: missing loads_skill");
  return {
    name: unquote(fm.name),
    description: fm.description ? unquote(fm.description) : "",
    loads_skill: unquote(fm.loads_skill),
    body,
  };
}

export function mdToCodexToml(a: CanonicalAgent): string {
  return `name = ${JSON.stringify(a.name)}
description = ${JSON.stringify(a.description)}
sandbox_mode = "read-only"
developer_instructions = """
${a.body}
"""
`;
}
