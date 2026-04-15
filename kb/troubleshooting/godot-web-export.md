# Godot Web Export Requirements

**Source:** Sprint 0 (Patch, S0-001)

## Problem
Godot web exports fail or produce broken builds if the renderer isn't set correctly.

## Solution
- Use `gl_compatibility` renderer in `project.godot` (`renderer/rendering_method="gl_compatibility"`)
- Vulkan (default) does NOT work for HTML5/web exports
- Export preset must target "Web" platform with `variant/thread_support=false` for broadest browser compatibility

## Entry Point
- `run/main_scene` in `project.godot` determines what the web export loads. If you add a new main scene (e.g., `game_main.tscn` replacing `main.tscn`), update this setting or the deployed game will show the old scene.
- **Source:** Sprint 3 — web export showed Sprint 1 arena demo until entry point was updated.

## set_script() Fails in Web Exports

**Source:** Sprint 5 (S5-001)

**Problem:** `Node2D.new()` followed by `set_script(load("res://script.gd"))` does NOT register virtual method overrides (`_draw()`, `_process()`, etc.) in Godot web exports. The node loads but virtual methods never fire — result is a blank/invisible node.

**Fix:** Preload the script and instantiate directly:
```gdscript
# WRONG (breaks in web export):
var node = Node2D.new()
node.set_script(load("res://my_script.gd"))

# RIGHT:
var MyScript = preload("res://my_script.gd")
var node = MyScript.new()
```

**Why:** In web exports, `set_script()` on an already-constructed bare node doesn't re-register virtual method overrides. The node's vtable is fixed at construction time. `preload().new()` constructs with the script already attached, so overrides register correctly.

**Rule:** Never use `set_script()` for nodes that rely on virtual methods. Always use `preload().new()`.

## Also
- Headless browsers (CI) lack WebGL — Godot stays in loading state. This is expected, not a bug.
- Godot's HTML shell hides `<body>` until WASM engine loads. Test for canvas presence in DOM, not body visibility.
