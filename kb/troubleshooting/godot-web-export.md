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

**Source:** Sprint 5 (S5-001), updated Sprint 7

**Problem:** `Node2D.new()` followed by `set_script(load("res://script.gd"))` does NOT register virtual method overrides (`_draw()`, `_process()`, etc.) in Godot web exports. The node loads but virtual methods never fire — result is a blank/invisible node.

**Fix:** Use scene instantiation — create a `.tscn` scene with the script attached, then preload and instantiate it:
```gdscript
# WRONG (breaks in web export):
var node = Node2D.new()
node.set_script(load("res://my_script.gd"))

# ALSO WRONG (Script.new() is unreliable in web exports):
var MyScript = preload("res://my_script.gd")
var node = MyScript.new()

# RIGHT — scene instantiation:
var scene = preload("res://my_node.tscn")
var node = scene.instantiate()
```

**Why:** In web exports, both `set_script()` and `Script.new()` can fail to properly register virtual method overrides. Scene instantiation (`preload().instantiate()`) is the only reliable method because Godot fully constructs the node with its script and overrides during scene loading.

**Rule:** Never use `set_script()` or bare `Script.new()` for nodes that rely on virtual methods in web exports. Always use scene instantiation (`preload("res://scene.tscn").instantiate()`).

## Also
- Headless browsers (CI) lack WebGL — Godot stays in loading state. This is expected, not a bug.
- Godot's HTML shell hides `<body>` until WASM engine loads. Test for canvas presence in DOM, not body visibility.
