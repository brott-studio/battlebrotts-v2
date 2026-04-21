extends CanvasLayer

signal resolved(trick_id: String, choice_key: String)

@onready var _overlay: ColorRect = $Overlay
@onready var _dialogue: Label = $Overlay/Panel/VBox/TopRow/Dialogue
@onready var _prompt: Label = $Overlay/Panel/VBox/Prompt
@onready var _btn_a: Button = $Overlay/Panel/VBox/Buttons/ChoiceA
@onready var _btn_b: Button = $Overlay/Panel/VBox/Buttons/ChoiceB
@onready var _btn_skip: Button = $Overlay/Panel/VBox/Buttons/Skip
@onready var _preview_a: Label = $Overlay/Panel/VBox/PreviewRow/PreviewA
@onready var _preview_b: Label = $Overlay/Panel/VBox/PreviewRow/PreviewB
@onready var _first_run_framing: Label = $Overlay/Panel/VBox/FirstRunFraming
@onready var _toast: Label = $Overlay/Toast

## S17.1-006 — First-run contextual framing for the `crate_find` trick.
## Key reserved by S17.1-004 (see first_run_state.gd §Consumers).
const CRATE_FIRST_RUN_KEY := "crate_first_run"
const CRATE_FRAMING_TEXT := "Crates are optional loot. Opening might give you an item \u2014 or nothing."
var _trick: Dictionary = {}
# S13.8: one-shot guard. Modal instances are single-use; shop_screen creates
# a fresh instance per visit, so we don't reset this. Re-entry is a no-op.
var _trick_shown: bool = false
# S17.1-005: one-shot resolution guard. First click/ESC locks all further
# input paths so A/B/skip cannot double-fire.
var _resolving: bool = false

func show_trick(trick: Dictionary) -> void:
	if _trick_shown:
		return
	_trick_shown = true
	_trick = trick
	_dialogue.text = trick.get("brottbrain_text", "")
	_prompt.text = trick.get("prompt", "")
	_btn_a.text = trick.get("choice_a", {}).get("label", "")
	_btn_b.text = trick.get("choice_b", {}).get("label", "")
	_btn_skip.text = "Not now"
	_toast.visible = false
	_maybe_show_first_run_framing(trick)
	_overlay.modulate.a = 0.0
	_btn_a.pressed.connect(func(): _on_choice("choice_a"))
	_btn_b.pressed.connect(func(): _on_choice("choice_b"))
	_btn_skip.pressed.connect(func(): _on_skip())
	_populate_previews(trick)
	create_tween().tween_property(_overlay, "modulate:a", 1.0, 0.2)

## S17.1-005 — ESC parity for the Skip button. Ignored until fade-in
## completes (guards against double-fire while buttons render).
func _unhandled_input(event: InputEvent) -> void:
	if _resolving or not _trick_shown:
		return
	if _overlay == null or _overlay.modulate.a < 0.95:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_skip()

## S17.1-005 — Populate PreviewA/PreviewB from the already-resolved trick
## dict (patched by shop_screen._prepare_trick_for_modal). No new RNG call.
## Row labels stay hidden for pure bolts/HP effects; visible only when a
## choice touches inventory (ITEM_GRANT / ITEM_LOSE).
func _populate_previews(trick: Dictionary) -> void:
	_preview_a.text = _preview_for_choice(trick.get("choice_a", {}))
	_preview_b.text = _preview_for_choice(trick.get("choice_b", {}))
	_preview_a.visible = _preview_a.text != ""
	_preview_b.visible = _preview_b.text != ""
	var gray := Color(0.85, 0.85, 0.85)
	_preview_a.add_theme_color_override("font_color", gray)
	_preview_b.add_theme_color_override("font_color", gray)
	_preview_a.add_theme_font_size_override("font_size", 12)
	_preview_b.add_theme_font_size_override("font_size", 12)

static func _name_from_token(tok: String) -> String:
	if tok == "":
		return ""
	var resolved: Dictionary = ItemTokens.resolve_token(tok)
	if resolved.is_empty():
		return ""
	return ItemTokens.display_name(resolved)

## Build a preview line for one choice. Covers the six effect-class rows
## from design §4.2; returns "" when no preview is earned.
static func _preview_for_choice(choice: Dictionary) -> String:
	if choice.is_empty():
		return ""
	var et = choice.get("effect_type")
	var et2 = choice.get("effect_type_2")
	var ev: String = str(choice.get("effect_value", ""))
	var ev2: String = str(choice.get("effect_value_2", ""))
	var EG = TrickChoices.EffectType.ITEM_GRANT
	var EL = TrickChoices.EffectType.ITEM_LOSE
	var BD = TrickChoices.EffectType.BOLTS_DELTA
	var item_et_name := ""
	var item_et2_name := ""
	if et == EG or et == EL:
		item_et_name = _name_from_token(ev)
	if et2 == EG or et2 == EL:
		item_et2_name = _name_from_token(ev2)
	# Trade: lose + grant
	if (et == EL and et2 == EG) or (et == EG and et2 == EL):
		var lose_name := item_et_name if et == EL else item_et2_name
		var grant_name := item_et_name if et == EG else item_et2_name
		if lose_name != "" and grant_name != "":
			return "You trade your %s for a %s." % [lose_name, grant_name]
	# Lose + bolts positive
	if et == EL and et2 == BD and int(choice.get("effect_value_2", 0)) > 0 and item_et_name != "":
		return "− %s   + %d bolts" % [item_et_name, int(choice["effect_value_2"])]
	if et2 == EL and et == BD and int(choice.get("effect_value", 0)) > 0 and item_et2_name != "":
		return "− %s   + %d bolts" % [item_et2_name, int(choice["effect_value"])]
	# Grant + bolts negative
	if et == EG and et2 == BD and int(choice.get("effect_value_2", 0)) < 0 and item_et_name != "":
		return "+ %s   − %d bolts" % [item_et_name, -int(choice["effect_value_2"])]
	if et2 == EG and et == BD and int(choice.get("effect_value", 0)) < 0 and item_et2_name != "":
		return "+ %s   − %d bolts" % [item_et2_name, -int(choice["effect_value"])]
	# Pure ITEM_LOSE
	if et == EL and item_et_name != "":
		return "− You lose your %s." % item_et_name
	if et2 == EL and item_et2_name != "":
		return "− You lose your %s." % item_et2_name
	# Pure ITEM_GRANT
	if et == EG and item_et_name != "":
		return "+ You receive a %s." % item_et_name
	if et2 == EG and item_et2_name != "":
		return "+ You receive a %s." % item_et2_name
	return ""

func _on_choice(key: String) -> void:
	if _resolving:
		return
	_resolving = true
	_btn_a.disabled = true
	_btn_b.disabled = true
	_btn_skip.disabled = true
	var btn: Button = _btn_a if key == "choice_a" else _btn_b
	var orig := btn.modulate
	btn.modulate = Color(0.0, 1.0, 1.0)
	await get_tree().create_timer(0.1).timeout
	btn.modulate = orig
	_toast.text = _trick[key]["flavor_line"]
	_toast.visible = true
	await get_tree().create_timer(1.0).timeout
	var tw := create_tween()
	tw.tween_property(_overlay, "modulate:a", 0.0, 0.15)
	await tw.finished
	resolved.emit(_trick["id"], key)

## S17.1-005 — Skip path: short dim flash, no flavor toast, fade out.
## Emits resolved(trick_id, "skip"). shop_screen bypasses apply_trick_choice.
func _on_skip() -> void:
	if _resolving:
		return
	_resolving = true
	_btn_a.disabled = true
	_btn_b.disabled = true
	_btn_skip.disabled = true
	var orig := _btn_skip.modulate
	_btn_skip.modulate = Color(0.8, 0.9, 1.0)
	await get_tree().create_timer(0.08).timeout
	_btn_skip.modulate = orig
	var tw := create_tween()
	tw.tween_property(_overlay, "modulate:a", 0.0, 0.15)
	await tw.finished
	var tid: String = String(_trick.get("id", ""))
	resolved.emit(tid, "skip")

## S17.1-006 — First-run framing: show a one-line context label above the
## existing dialogue the first time the player encounters a `crate_find`
## trick. `mark_seen` fires on show (not on resolve), so Skip / ESC / any
## dismissal still counts as having seen the framing. See design §4.
func _maybe_show_first_run_framing(trick: Dictionary) -> void:
	if _first_run_framing == null:
		return
	_first_run_framing.visible = false
	if String(trick.get("id", "")) != "crate_find":
		return
	var frs: Node = _get_first_run_state()
	if frs == null:
		return
	if bool(frs.call("has_seen", CRATE_FIRST_RUN_KEY)):
		return
	_first_run_framing.text = CRATE_FRAMING_TEXT
	_first_run_framing.visible = true
	frs.call("mark_seen", CRATE_FIRST_RUN_KEY)

func _get_first_run_state() -> Node:
	if not is_inside_tree():
		return null
	var tree := get_tree()
	if tree == null:
		return null
	var root := tree.get_root()
	if root == null:
		return null
	return root.get_node_or_null("FirstRunState")
