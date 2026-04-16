# GDScript `max()`/`min()` Return Variant — Use Typed Alternatives

**Source:** Sprint 7 (S7-001)

## Problem

In GDScript 4.x, `max()` and `min()` accept `Variant` arguments and return `Variant`. When used with `:=` (inferred type), the variable becomes `Variant` — which causes errors in strict mode and can trigger "cannot infer type" failures in web exports.

```gdscript
# BAD — tray_y becomes Variant, `:=` inference fails in strict mode:
var tray_y := max(y + 15, 380)
```

## Fix

Use the typed alternatives and explicit type annotations:

| Function | Typed Alternative |
|----------|-------------------|
| `max()` | `maxi()` (int), `maxf()` (float) |
| `min()` | `mini()` (int), `minf()` (float) |
| `clamp()` | `clampi()` (int), `clampf()` (float) |

```gdscript
# GOOD:
var tray_y: int = maxi(y + 15, 380)
```

## Why It Matters

- Strict mode treats Variant inference as an error
- Web exports may behave differently with Variant types
- Explicit types catch bugs at compile time, not runtime

## Rule

Never use `max()`/`min()`/`clamp()` with `:=`. Use the typed `i`/`f` variants with explicit type annotations.
