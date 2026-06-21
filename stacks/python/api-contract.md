# Stack pack: python — api-contract
extends: core/skills/api-contract/SKILL.md

## Stack-specific signals
- FastAPI/Django route response shape changed (field renamed/removed, status code changed) with no versioning.
- Pydantic model `Optional[T] = None` where the wire contract was required (or vice versa) → schema drift.
- Returning a raw `dict` / `Any` from a typed route instead of the declared `response_model`.
- Serialization surprises: `datetime` → ISO string vs timestamp, `Decimal`/`UUID` encoding, `Enum` value vs name.
- Breaking changes to a Pydantic model (renamed field, removed field, tightened validator) consumed by clients without migration.

## Stack-specific remedies
- Declare and honor a `response_model` (Pydantic); version breaking route changes (URL prefix or header).
- Make optionality match the documented schema; configure `model_config` json encoders for dates/Decimal/UUID.

## Stack-specific severity guidance
- Response field renamed/removed with no versioning: High.
- `response_model=None`/`Any` on a public endpoint: Medium/High (hides contract).
