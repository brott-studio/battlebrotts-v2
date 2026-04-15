# KB: Latent Bugs in Inactive Code Paths

**Source:** Sprint 1 audit  
**Category:** Code Quality  

## Pattern

Code that passes all tests because a feature isn't fully activated yet, but contains bugs that will surface when the feature goes live.

## Example (Sprint 1)

The Overclock module has two bugs:
1. `overclock_recovery` flag is set to `true` on deactivation but never cleared when cooldown expires → permanent -20% fire rate penalty
2. Cooldown value is 7.0 (comment says "4s active + 3s recovery") but it's applied AFTER the 4s duration, creating an 11s cycle instead of 7s

Both bugs pass all S1 tests because modules don't auto-activate yet. They'll break in the sprint that enables module activation.

## Mitigation

During code review, explicitly ask: **"Does this code work when the feature is fully enabled, not just in current sprint scope?"**

For each deferred feature, check:
- Are state flags properly managed through the full lifecycle (activate → active → deactivate → cooldown → ready)?
- Do timer-based systems have proper cleanup hooks when timers expire?
- Are there any "set but never cleared" flags?
