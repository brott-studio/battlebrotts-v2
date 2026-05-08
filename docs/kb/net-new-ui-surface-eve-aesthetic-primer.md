# KB: Net-New UI Surface with EVE-Aesthetic Primer

**Source:** S24.2 (Arc E — Audio Depth) — Mixer Settings Panel
**Owner:** battlebrotts-v2

---

## Context

BattleBrotts targets the EVE-from-WALL-E visual pillar: professional, restrained, clean, polished, smooth curves, intentional color. Apply this checklist when adding a net-new UI panel.

---

## Panel Container Style

```gdscript
var style := StyleBoxFlat.new()
style.bg_color = Color("#2A2A2A")
style.corner_radius_top_left    = 12   # >= 8px — EVE silhouette
style.corner_radius_top_right   = 12
style.corner_radius_bottom_left = 12
style.corner_radius_bottom_right = 12
style.content_margin_left   = 24.0
style.content_margin_right  = 24.0
style.content_margin_top    = 20.0
style.content_margin_bottom = 20.0
add_theme_stylebox_override("panel", style)
```

## Typography and Color

```gdscript
const COLOR_CREAM := Color("#F4E4BC")   # Primary text
const COLOR_MUTED := Color("#A0A0A0")   # Secondary labels
```

- Title: `font_size = 28`, `COLOR_CREAM`, centered.
- Body: `font_size = 18`, `COLOR_CREAM`.
- No neon. No saturated accent text. One font size per role.

## Layout

- Single-column `VBoxContainer` with `separation = 16`.
- Row-level `HBoxContainer` with `separation = 8-12`.
- **No Apply/Save button.** Changes are live (`value_changed` / `toggled` write immediately).

## Sliders (HSlider)

- `size_flags_horizontal = Control.SIZE_EXPAND_FILL`
- **No dB numeric readout.** Labels only ("Master", "SFX", "Music").
- Fixed-width label column: `custom_minimum_size = Vector2(72, 0)`.

## Anti-Patterns

| Anti-pattern | Why |
|---|---|
| Hard-cornered panel | EVE silhouette is round |
| Neon slider accent | Color as decoration |
| dB readout label | Breaks "clean" pillar |
| 3+ competing font sizes | Breaks "one voice per screen" |
| Apply/Save button | Feels unfinished |
| Emoji in labels | Violates "no emoji UI" |

## Modal Presentation

```gdscript
# Guard double-open
if get_node_or_null("PanelName") != null:
    return
var panel := panel_scene.instantiate() as Control
panel.name = "PanelName"
panel.set_anchors_preset(Control.PRESET_CENTER)
add_child(panel)
# Dismiss via queue_free() on Close button
```

## References

- `godot/ui/mixer_settings_panel.gd`
- `docs/kb/ux-vision.md`
- `audits/battlebrotts-v2/v2-sprint-24.2.md`
