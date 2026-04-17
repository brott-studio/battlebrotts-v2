## Test utilities for BattleBrotts test suite.
## Added in S16.1-004 to support `skip-with-reason` quarantines of
## out-of-scope combat regressions (see sprints/sprint-16.md carry-forward).
class_name TestUtil
extends Object

## Prints a standardized SKIP line and returns true so the caller can
## `if TestUtil.skip_with_reason(...): return` before running the assertions.
## Does NOT touch the caller's pass/fail counters — quarantined cases
## are simply not executed.
static func skip_with_reason(test_name: String, reason: String) -> bool:
	print("  SKIP: %s — %s — carry-forward to future gameplay sprint (see sprints/sprint-16.md)" % [test_name, reason])
	return true
