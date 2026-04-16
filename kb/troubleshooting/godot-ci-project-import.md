# Godot CI: Project Import Required Before Tests

**Source:** Sprint 8 audit — Godot unit test CI job fails on first run
**Date:** 2026-04-16

## Problem

Running `godot --headless --path godot/ --script res://tests/test_runner.gd` in CI fails with:

```
SCRIPT ERROR: Parse Error: Could not find type "ChassisData" in the current scope.
```

All autoloads (`ChassisData`, `WeaponData`, `CombatSim`, etc.) are unresolved.

## Cause

Godot must import the project before autoloads are registered. A local Godot install has the project already imported (cached in `.godot/`), but a fresh CI environment does not.

## Fix

Add an import step before running tests:

```yaml
- name: Import Godot project
  run: godot --headless --path godot/ --import

- name: Run Godot tests
  run: godot --headless --path godot/ --script res://tests/test_runner.gd
```

Alternative: `godot --headless --path godot/ --editor --quit` also triggers import.

## Key Insight

Tests passing locally but failing in CI is almost always a missing import. The `.godot/` directory (which contains imported resources and autoload registrations) is gitignored and must be regenerated in CI.
