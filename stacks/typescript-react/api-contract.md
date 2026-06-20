# Stack pack: typescript-react — api-contract
extends: core/skills/api-contract/SKILL.md

## Stack-specific signals
- `fetch`/`axios` responses typed as `any` or cast (`as User`) instead of validated → contract drift between client and server.
- Response shape assumed from the server with no runtime validation (Zod / valibot / runtime guard) on external data.
- `Date` fields received as strings treated as `Date` objects, or vice versa, across the wire.
- Optional fields treated as required (or vice versa) on the client.
- Discriminated unions on the server flattened to loose object types on the client.
- Breaking shape changes consumed without a client migration.

## Stack-specific remedies
- Define a single schema (e.g. Zod) shared by client and server; infer the TS type from it.
- Validate at the boundary; narrow unknown input into a typed model before use.
- Model the wire representation explicitly (ISO strings for dates) and convert at the edge.

## Stack-specific severity guidance
- `any`/cast at the API boundary hiding a real shape mismatch: High.
- Missing runtime validation on untrusted external data: High when it can drive security/flow decisions.
