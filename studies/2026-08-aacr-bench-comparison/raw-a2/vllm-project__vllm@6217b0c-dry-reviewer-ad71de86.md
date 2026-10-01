<!-- vllm-project__vllm@6217b0c dry-reviewer; verbatim final answer -->
## DRY findings: none

This change doesn't duplicate or reinvent anything that already exists in the repo.

- **No shared helper exists for this.** I searched `vllm/` for code that loops over children, catches each exception, logs it and re-raises (`exceptions.append`, `exceptions[0]`, `ExceptionGroup`, `errors.append(e)`, "during ... shutdown" log messages, and helper names like `call_all` or `close_all`). The only hits were the new lines at `multi_connector.py:98` and `:100`.
- **The other `shutdown` implementations follow a different pattern.** None of them aggregates exceptions, so none is a helper this code could call:
  - `vllm/v1/utils.py:302` terminates, joins and then kills processes.
  - `vllm/v1/executor/multiproc_executor.py:296` closes worker pipes and ensures the worker processes exit.
  - `vllm/v1/core/sched/scheduler.py:1188` calls `shutdown()` on at most two members directly, with no try/except.
  - `vllm/v1/worker/gpu_worker.py:604` hands off to `ensure_kv_transfer_shutdown()`.
  - The base-class method `KVConnectorBase_V1.shutdown()` at `vllm/distributed/kv_transfer/kv_connector/v1/base.py:229` is the method being overridden, not a helper.
- **The loop matches the rest of the file.** Every other method in `MultiConnector` also loops over `self._connectors`, for example `register_kv_caches` at line 70 and `clear_connector_metadata` at line 86. `shutdown()` is the only one that needs per-child error isolation, so it has only one call site and no case for a shared helper.

## Files examined
examined: [vllm/distributed/kv_transfer/kv_connector/v1/multi_connector.py]
not_examined: []
