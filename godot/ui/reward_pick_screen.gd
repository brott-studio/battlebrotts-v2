## reward_pick_screen.gd — S25.5: Post-battle item reward selection.
class_name RewardPickScreen
extends Control

signal picked(item: Dictionary)  ## item = {category, type, display_name} or {} for duplicate

var _run_state: RunState = null
var _rng: RandomNumberGenerator

## S25.9: Background tint per tier for visual reward-escalation.
## battle_index is 0-indexed (idx 0–2 = battles 1–3 T1, etc.)
static func _bg_color_for_battle(battle_index: int) -> Color:
	if battle_index >= 13:  ## pre-boss (battle 14, 0-indexed 13)
		return Color(1.0, 0.55, 0.25)   ## red/gold
	if battle_index >= 7:   ## T3/T4 (battles 8–13)
		return Color(0.92, 0.92, 0.95)  ## silver-white
	if battle_index >= 3:   ## T2 (battles 4–7)
		return Color(0.78, 0.55, 0.35)  ## bronze
	return Color(0.65, 0.72, 0.85)      ## T1 (battles 1–3) grey-blue

func setup(run_state: RunState) -> void:
	_run_state = run_state
	## HUD bar at top
	var hud := RunHudBar.new()
	var vp_w: float = (get_viewport_rect().size.x as float) if get_viewport() else 1280.0
	hud.size = Vector2(vp_w, 36)
	hud.position = Vector2(0, 0)
	add_child(hud)
	hud.setup(run_state)
	_build_reward_ui()
	## S25.9: Tier-based background tint (visual escalation per tier)
	modulate = _bg_color_for_battle(run_state.current_battle_index)

func _build_reward_ui() -> void:
	## Seed: deterministic per battle
	var reward_seed := _run_state.seed * 31 + _run_state.current_battle_index
	_rng = RandomNumberGenerator.new()
	_rng.seed = reward_seed

	## Title
	var title := Label.new()
	title.text = "🎁 CHOOSE YOUR REWARD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.position = Vector2(290, 60)
	title.size = Vector2(700, 50)
	add_child(title)

	## Build eligible pool (exclude equipped items)
	var eligible: Array[Dictionary] = []
	for item in ItemPool.FULL_ITEM_POOL:
		if not _is_equipped(item):
			eligible.append(item)

	## Duplicate fallback path
	if eligible.size() < 3:
		var cont_lbl := Label.new()
		cont_lbl.text = "All items collected! You've mastered the build.\nDuplicate — spare parts."
		cont_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cont_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cont_lbl.position = Vector2(390, 150)
		cont_lbl.size = Vector2(500, 80)
		add_child(cont_lbl)
		var cont_btn := Button.new()
		cont_btn.text = "Continue"
		cont_btn.position = Vector2(515, 260)
		cont_btn.size = Vector2(250, 60)
		cont_btn.pressed.connect(func(): picked.emit({}))
		add_child(cont_btn)
		return

	## Shuffle and pick 3
	var shuffled := eligible.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Dictionary = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = tmp
	var picks := shuffled.slice(0, 3)

	## Render 3 item cards
	var card_xs := [140.0, 440.0, 740.0]
	for i in range(3):
		var item: Dictionary = picks[i]
		var btn := Button.new()
		btn.name = "ItemCard_%d" % i
		btn.text = item["display_name"]
		btn.position = Vector2(card_xs[i], 150)
		btn.size = Vector2(220, 120)
		btn.add_theme_font_size_override("font_size", 18)
		var it := item  ## closure capture
		btn.pressed.connect(func():
			_run_state.add_item(it["category"], it["type"])
			picked.emit(it)
		)
		add_child(btn)
		## Category label
		var cat_lbl := Label.new()
		cat_lbl.text = String(item["category"]).capitalize()
		cat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cat_lbl.position = Vector2(card_xs[i], 280)
		cat_lbl.size = Vector2(220, 24)
		add_child(cat_lbl)
		## Description label
		var full_data: Dictionary = {}
		match item["category"]:
			"weapon": full_data = WeaponData.WEAPONS.get(item["type"], {})
			"armor":  full_data = ArmorData.ARMORS.get(item["type"], {})
			"module": full_data = ModuleData.MODULES.get(item["type"], {})
		var description: String = full_data.get("description", "")
		var desc_lbl := Label.new()
		desc_lbl.text = description
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.position = Vector2(card_xs[i], 310)
		desc_lbl.size = Vector2(220, 60)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.modulate = Color(0.8, 0.8, 0.8, 1.0)
		add_child(desc_lbl)

func _is_equipped(item: Dictionary) -> bool:
	match item["category"]:
		"weapon": return item["type"] in _run_state.equipped_weapons
		"armor":  return _run_state.equipped_armor == item["type"]
		"module": return item["type"] in _run_state.equipped_modules
	return false
