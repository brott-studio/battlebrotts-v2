## Shop Screen — Sprint 13.4: card grid MVP (pivot from balance → shop visual)
##
## Card grid layout per Gizmo's spec (docs/design/sprint13.4-shop-card-grid.md):
## - 3 cols at viewport width >= 1024, else 2 cols.
## - Cards 200x240 with placeholder art tile (category-colored), name, archetype tag, price.
## - Tap-to-expand inline stats panel below the row (not modal). Buy button lives in the panel.
## - Sections WEAPONS -> ARMOR -> CHASSIS -> MODULES.
## - Owned: 50% opacity + green check. Unaffordable: red price. continue_pressed unchanged.
##
## Implementation uses VBox-of-HBox rows (not GridContainer) so we can insert a
## full-width ExpandPanel between rows deterministically — Ett flagged the
## GridContainer reflow as flaky for mid-grid inserts.
class_name ShopScreen
extends Control

signal item_purchased(category: String, type: int)
signal continue_pressed

# Palette (see design doc §5)
const COLOR_CREAM := Color("#F4E4BC")
const COLOR_MUTED := Color("#A0A0A0")
const COLOR_UNAFFORDABLE := Color("#D04040")
const COLOR_OWNED_GREEN := Color("#6FCF6F")

const CAT_COLORS := {
	"weapon":  { "fill": Color("#8B2E2E"), "border": Color("#D4A84A") },
	"armor":   { "fill": Color("#2E5A8B"), "border": Color("#8FAECB") },
	"chassis": { "fill": Color("#4A4A4A"), "border": Color("#A0A0A0") },
	"module":  { "fill": Color("#2E6B4A"), "border": Color("#7BCA9E") },
}

const CARD_W := 200
const CARD_H := 240
const ART_H := 120
const GUTTER := 16
const DESKTOP_MIN_W := 1024

# Sprint 13.5 D2: SFX tokens (safe-load; .ogg files are not committed)
const SFX_BUY_SUCCESS := "res://audio/sfx/shop_buy_success.ogg"
const SFX_BUY_FAIL := "res://audio/sfx/shop_buy_fail.ogg"
const SFX_CARD_TAP := "res://audio/sfx/shop_card_tap.ogg"

var game_state: GameState
var _content_vbox: VBoxContainer
var _expanded_key: String = ""
var _forced_width: int = -1  # test hook; -1 = use viewport width
var _shop_audio: AudioStreamPlayer

# [S17.1-001] Preserves ScrollArea scroll position across full _build_ui()
# teardown/rebuild cycles (card tap, buy, trick modal). Save on rebuild
# entry, restore one frame later via call_deferred so the new VBox has
# finalized its minimum size and ScrollContainer has clamped max scroll.
var _saved_scroll_v: int = 0

# D3: session-local "seen" set + active pulse tween registry.
# STATIC: persists across ShopScreen instances within a single game session
# (game_main creates a fresh ShopScreen each shop phase). This preserves
# "new item" semantics so already-seen items don't re-pulse every visit.
# Tests must reset this dict in setup for isolation.
# Keying: "{category}:{type}" — see _key_for (which uses "_"); normalized here.
static var _seen_shop_items: Dictionary = {}
var _active_pulses: Dictionary = {}  # key -> Tween
var _last_pulse_count: int = 0  # test observability

## S13.6: Scrapyard trick choice modal is shown once per shop visit before
## the grid builds. This flag prevents re-trigger on subsequent _build_ui()
## rebuilds (e.g. after a purchase). Fresh ShopScreen instance per shop
## phase (see game_main._show_shop) → naturally resets.
var _trick_shown: bool = false
var _skip_trick: bool = false  # test hook: bypass modal in unit tests

func _ready() -> void:
	_shop_audio = AudioStreamPlayer.new()
	add_child(_shop_audio)

func _play_sfx(path: String) -> void:
	if _shop_audio == null:
		return
	var stream = load(path) if ResourceLoader.exists(path) else null
	if stream:
		_shop_audio.stream = stream
		_shop_audio.play()

# --- Public API (kept backwards-compatible) ---

func setup(state: GameState) -> void:
	game_state = state
	_maybe_show_trick_then_build()

func setup_for_viewport(state: GameState, viewport_w: int) -> void:
	## Test hook: force a specific viewport width for deterministic layout checks.
	game_state = state
	_forced_width = viewport_w
	# Tests that drive setup_for_viewport expect synchronous grid construction;
	# do NOT show the modal here (it's animated + awaited). Integration is
	# covered separately via setup().
	_trick_shown = true
	_build_ui()

## S13.6: Scrapyard-only trick-choice modal hook. Awaits the modal's
## `resolved` signal, applies the choice, then builds the shop grid. All
## other leagues build immediately. Safe to call multiple times; only the
## first call per ShopScreen instance triggers the modal.
func _maybe_show_trick_then_build() -> void:
	if _trick_shown or _skip_trick or game_state == null:
		_trick_shown = true
		_build_ui()
		return
	_trick_shown = true
	if game_state.current_league != "scrapyard":
		_build_ui()
		return
	var trick: Dictionary = game_state.pick_unseen_trick()
	if trick.is_empty():
		_build_ui()
		return
	var modal_scene: PackedScene = load("res://ui/trick_choice_modal.tscn") as PackedScene
	if modal_scene == null:
		push_warning("[S13.6] trick_choice_modal.tscn missing; skipping")
		_build_ui()
		return
	var modal := modal_scene.instantiate()
	add_child(modal)
	# S13.8 item 5: pre-resolve pool tokens + substitute {item_name} so the
	# modal's flavor toast matches what apply_trick_choice will actually
	# grant/lose. We mutate a deep-duplicated trick dict (no aliasing).
	var patched: Dictionary = _prepare_trick_for_modal(trick)
	modal.show_trick(patched)
	var result: Array = await modal.resolved
	# result = [trick_id, choice_key]
	var choice_key: String = String(result[1]) if result.size() >= 2 else "choice_a"
	# S13.8: queue_free BEFORE apply so modal is always reclaimed,
	# even if apply_trick_choice raises on malformed trick data.
	modal.queue_free()
	# S17.1-005 — Skip path: bypass apply_trick_choice entirely. No bolts/HP
	# /inventory change, no flavor toast. Silence is the reward.
	if choice_key == "skip":
		_build_ui()
		return
	# S13.8 item 5: pass patched dict so apply operates on the pre-resolved
	# pool tokens (RNG-consistent with the toast the modal showed).
	game_state.apply_trick_choice(patched, choice_key)
	_build_ui()

## S13.8 item 5 — Duplicate a trick dict and pre-resolve any pool ITEM tokens
## to concrete direct tokens, then substitute `{item_name}` placeholders in
## each choice's flavor_line. Returns the patched copy. Leaves the original
## trick (and any flavor without `{item_name}`) untouched.
func _prepare_trick_for_modal(trick: Dictionary) -> Dictionary:
	var patched: Dictionary = trick.duplicate(true)
	for key in ["choice_a", "choice_b"]:
		if not patched.has(key):
			continue
		var c: Dictionary = patched[key]
		for field_t in ["effect_type", "effect_type_2"]:
			if not c.has(field_t):
				continue
			var et = c[field_t]
			if et != TrickChoices.EffectType.ITEM_GRANT and et != TrickChoices.EffectType.ITEM_LOSE:
				continue
			var field_v: String = field_t.replace("type", "value")
			var tok: String = String(c.get(field_v, ""))
			if tok.begins_with("random_"):
				var resolved: Dictionary = ItemTokens.resolve_token(tok)
				if not resolved.is_empty():
					c[field_v] = String(resolved["token"])
		c["flavor_line"] = _substitute_item_name(String(c.get("flavor_line", "")), c)
	return patched

## S13.8 item 5 — Replace `{item_name}` with the display name of the ITEM_GRANT
## or ITEM_LOSE token on `choice`. Leaves the string unchanged on any miss
## (no placeholder, non-item effect, unresolvable token). AC5.2: QA catches
## authoring mistakes because the placeholder stays visible.
func _substitute_item_name(flavor: String, choice: Dictionary) -> String:
	if "{item_name}" not in flavor:
		return flavor
	var tok: String = ""
	var et = choice.get("effect_type")
	var et2 = choice.get("effect_type_2")
	if et == TrickChoices.EffectType.ITEM_GRANT or et == TrickChoices.EffectType.ITEM_LOSE:
		tok = String(choice.get("effect_value", ""))
	elif et2 == TrickChoices.EffectType.ITEM_GRANT or et2 == TrickChoices.EffectType.ITEM_LOSE:
		tok = String(choice.get("effect_value_2", ""))
	if tok == "":
		return flavor
	var resolved: Dictionary = ItemTokens.resolve_token(tok)
	var name: String = ItemTokens.display_name(resolved)
	if name == "":
		return flavor
	return flavor.replace("{item_name}", name)

# --- UI construction ---

func _build_ui() -> void:
	# [S17.1-001] Capture current scroll position BEFORE tearing down the
	# tree so we can restore it after rebuild (prevents jump-to-top on card
	# tap / buy / collapse).
	var prior_scroll := get_node_or_null("ScrollArea") as ScrollContainer
	if prior_scroll != null:
		_saved_scroll_v = prior_scroll.scroll_vertical

	# Remove children immediately (queue_free is deferred and leaves stale
	# nodes visible to the tree between rebuilds — breaks tests and can
	# briefly show two expanded panels during rapid taps).
	for c in get_children():
		if c == _shop_audio:
			continue
		remove_child(c)
		c.queue_free()

	var viewport_w := _resolve_width()
	var cols := 3 if viewport_w >= DESKTOP_MIN_W else 2

	# --- Header (bolts counter top-right, title top-left) ---
	var header := Control.new()
	header.name = "Header"
	header.custom_minimum_size = Vector2(viewport_w, 60)
	header.position = Vector2(0, 0)
	add_child(header)

	var title := Label.new()
	title.text = "SHOP"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", COLOR_CREAM)
	title.position = Vector2(20, 10)
	header.add_child(title)

	var bolts := Label.new()
	bolts.name = "BoltsCounter"
	bolts.text = "%d 🔩" % game_state.bolts
	bolts.add_theme_font_size_override("font_size", 36)
	bolts.add_theme_color_override("font_color", COLOR_CREAM)
	bolts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bolts.size = Vector2(300, 50)
	bolts.position = Vector2(viewport_w - 320, 5)
	header.add_child(bolts)

	# --- Scroll area for cards ---
	var scroll := ScrollContainer.new()
	scroll.name = "ScrollArea"
	scroll.position = Vector2(0, 70)
	scroll.custom_minimum_size = Vector2(viewport_w, 600)
	scroll.size = Vector2(viewport_w, 600)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# [S17.1-001] Wheel step uses Godot engine defaults — intentional.
	# Custom multiplier considered and rejected (see design §3.2): risks
	# breaking trackpad-smooth-scroll + keyboard scroll + middle-click pan.
	scroll.scroll_deadzone = 0
	add_child(scroll)

	_content_vbox = VBoxContainer.new()
	_content_vbox.name = "Content"
	_content_vbox.add_theme_constant_override("separation", 12)
	_content_vbox.custom_minimum_size = Vector2(viewport_w, 0)
	scroll.add_child(_content_vbox)

	# --- Sections in spec order ---
	_last_pulse_count = 0  # D3: reset per-build pulse counter
	_build_section("WEAPONS", "weapon", GameState.WEAPON_PRICES, cols, func(t): return WeaponData.get_weapon(t), game_state.owned_weapons)
	_build_section("ARMOR",   "armor",  GameState.ARMOR_PRICES,  cols, func(t): return ArmorData.get_armor(t),  game_state.owned_armor)
	_build_section("CHASSIS", "chassis",GameState.CHASSIS_PRICES,cols, func(t): return ChassisData.get_chassis(t), game_state.owned_chassis)
	_build_section("MODULES", "module", GameState.MODULE_PRICES, cols, func(t): return ModuleData.get_module(t), game_state.owned_modules)

	# --- Continue button ---
	var btn := Button.new()
	btn.name = "ContinueButton"
	btn.text = "Continue →"
	btn.position = Vector2(viewport_w - 220, 680)
	btn.size = Vector2(200, 50)
	btn.add_theme_font_size_override("font_size", 18)
	btn.pressed.connect(func(): continue_pressed.emit())
	add_child(btn)

	# [S17.1-001] Restore scroll position on next frame (after layout so
	# ScrollContainer.max_scroll_v reflects new content). Engine clamps to
	# [0, max_scroll_v] so large/stale values resolve safely.
	call_deferred("_restore_scroll")

func _restore_scroll() -> void:
	var scroll := get_node_or_null("ScrollArea") as ScrollContainer
	if scroll == null:
		return
	scroll.scroll_vertical = _saved_scroll_v

func _resolve_width() -> int:
	if _forced_width > 0:
		return _forced_width
	var vp := get_viewport()
	if vp != null:
		var sz := vp.get_visible_rect().size
		if sz.x > 0:
			return int(sz.x)
	return 1280  # sensible default for headless/startup

func _build_section(title: String, category: String, prices: Dictionary, cols: int, data_fn: Callable, owned: Array) -> void:
	# Section container
	var section := VBoxContainer.new()
	section.name = "Section_%s" % title
	section.add_theme_constant_override("separation", 8)

	# Section header
	var lbl := Label.new()
	lbl.text = "— %s —" % title
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", COLOR_CREAM)
	section.add_child(lbl)

	# Collect items for this section
	var items: Array = []
	for t in prices.keys():
		var d: Dictionary = data_fn.call(t)
		items.append({
			"category": category,
			"type": int(t),
			"data": d,
			"price": int(prices[t]),
			"owned": t in owned,
			"name": String(d.get("name", "???")),
			"archetype": String(d.get("archetype", "")),
		})

	# Rows of `cols` cards
	var row_index := 0
	var i := 0
	while i < items.size():
		var row_items: Array = items.slice(i, min(i + cols, items.size()))
		var row := HBoxContainer.new()
		row.name = "Row_%s_%d" % [title, row_index]
		row.add_theme_constant_override("separation", GUTTER)
		for it in row_items:
			row.add_child(_build_card(it))
		section.add_child(row)

		# Expand panel goes BELOW this row if any of its cards is the expanded one
		for it in row_items:
			var key := _key_for(it)
			if key == _expanded_key:
				section.add_child(_build_expand_panel(it))
				break

		i += cols
		row_index += 1

	_content_vbox.add_child(section)

func _key_for(it: Dictionary) -> String:
	return "%s_%d" % [String(it["category"]), int(it["type"])]

# --- Card ---

func _build_card(it: Dictionary) -> Control:
	var category := String(it["category"])
	var item_name := String(it["name"])
	var archetype := String(it["archetype"])
	var price := int(it["price"])
	var owned := bool(it["owned"])
	var key := _key_for(it)

	var card := Button.new()  # Button to get built-in click handling
	card.name = "Card_%s" % key
	card.flat = true
	card.toggle_mode = false
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.size = Vector2(CARD_W, CARD_H)
	card.set_meta("category", category)
	card.set_meta("type", int(it["type"]))
	card.set_meta("price", price)
	card.set_meta("owned", owned)
	card.set_meta("name", item_name)

	# Background panel
	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.color = Color(0.12, 0.12, 0.14)
	bg.position = Vector2.ZERO
	bg.size = Vector2(CARD_W, CARD_H)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(bg)

	# Art tile (placeholder: category fill + border + monogram)
	var art := Panel.new()
	art.name = "Art"
	art.position = Vector2(0, 0)
	art.size = Vector2(CARD_W, ART_H)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = CAT_COLORS[category]["fill"]
	sb.border_color = CAT_COLORS[category]["border"]
	sb.set_border_width_all(3)
	art.add_theme_stylebox_override("panel", sb)
	card.add_child(art)

	# Monogram: first letter of the last word of the name (spec §7: multi-word items)
	var glyph := _monogram(item_name)
	var mono := Label.new()
	mono.name = "Monogram"
	mono.text = glyph
	mono.add_theme_font_size_override("font_size", 48)
	mono.add_theme_color_override("font_color", COLOR_CREAM)
	mono.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mono.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mono.position = Vector2(0, 0)
	mono.size = Vector2(CARD_W, ART_H)
	mono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(mono)

	# Name
	var name_lbl := Label.new()
	name_lbl.name = "Name"
	name_lbl.text = item_name
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", COLOR_CREAM)
	name_lbl.position = Vector2(10, ART_H + 10)
	name_lbl.size = Vector2(CARD_W - 20, 22)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_lbl)

	# Archetype tag: "{archetype} • {Category}" (Category capitalized)
	var tag := Label.new()
	tag.name = "Tag"
	var arch_str := archetype
	if arch_str == "":
		arch_str = _category_display(category)
		tag.text = arch_str
	else:
		tag.text = "%s • %s" % [arch_str, _category_display(category)]
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_color_override("font_color", COLOR_MUTED)
	tag.position = Vector2(10, ART_H + 34)
	tag.size = Vector2(CARD_W - 20, 16)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(tag)

	# [S17.1-003] Inline description — always visible, no hover required.
	# Reads existing data["description"] field; em-dash fallback when empty.
	# Full text remains available via existing expand-panel / hover path.
	var data_dict: Dictionary = it["data"] if it.has("data") else {}
	var desc_str: String = String(data_dict.get("description", ""))
	if desc_str == "":
		desc_str = "—"
	var desc_lbl := Label.new()
	desc_lbl.name = "Description"
	desc_lbl.text = desc_str
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", COLOR_MUTED)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	desc_lbl.clip_text = true
	desc_lbl.position = Vector2(10, ART_H + 54)
	desc_lbl.size = Vector2(CARD_W - 20, 32)
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(desc_lbl)

	# Price (bottom-right)
	var price_lbl := Label.new()
	price_lbl.name = "Price"
	if owned:
		price_lbl.text = "✓ Owned"
		price_lbl.add_theme_color_override("font_color", COLOR_OWNED_GREEN)
	elif price == 0:
		price_lbl.text = "Free"
		price_lbl.add_theme_color_override("font_color", COLOR_CREAM)
	else:
		price_lbl.text = "%d 🔩" % price
		if price > game_state.bolts:
			price_lbl.add_theme_color_override("font_color", COLOR_UNAFFORDABLE)
		else:
			price_lbl.add_theme_color_override("font_color", COLOR_CREAM)
	price_lbl.add_theme_font_size_override("font_size", 18)
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_lbl.position = Vector2(10, CARD_H - 32)
	price_lbl.size = Vector2(CARD_W - 20, 22)
	price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(price_lbl)

	# Owned badge overlay (green check top-right of art)
	if owned:
		var badge := Label.new()
		badge.name = "OwnedBadge"
		badge.text = "✓"
		badge.add_theme_font_size_override("font_size", 28)
		badge.add_theme_color_override("font_color", COLOR_OWNED_GREEN)
		badge.position = Vector2(CARD_W - 34, 6)
		badge.size = Vector2(28, 28)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(badge)
		card.modulate = Color(1, 1, 1, 0.5)

	# D3: new-item pulse — apply before returning so tween lives on the card.
	if not _seen_shop_items.has(key):
		var hl := ColorRect.new()
		hl.name = "NewHighlight"
		hl.color = Color(COLOR_CREAM.r, COLOR_CREAM.g, COLOR_CREAM.b, 0.0)
		hl.position = Vector2.ZERO
		hl.size = Vector2(CARD_W, CARD_H)
		hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(hl)
		var tw := create_tween()
		tw.set_loops(2)
		tw.tween_property(hl, "color:a", 0.4, 1.0)
		tw.tween_property(hl, "color:a", 0.0, 1.0)
		_active_pulses[key] = tw
		_last_pulse_count += 1
		_seen_shop_items[key] = true

	# Tap handler — capture the full dict
	card.pressed.connect(_toggle_expand.bind(it))
	return card

func _monogram(item_name: String) -> String:
	# Use first letter of the last word so "Plasma Cutter" -> "C" vs "Plating" -> "P".
	var parts := item_name.strip_edges().split(" ", false)
	if parts.size() == 0:
		return "?"
	var last: String = String(parts[parts.size() - 1])
	if last.length() == 0:
		return "?"
	return last.substr(0, 1).to_upper()

func _category_display(category: String) -> String:
	match category:
		"weapon": return "Weapon"
		"armor": return "Armor"
		"chassis": return "Chassis"
		"module": return "Module"
	return category.capitalize()

# --- Expand panel ---

func _toggle_expand(it: Dictionary) -> void:
	var key := _key_for(it)
	if _expanded_key == key:
		_expanded_key = ""
	else:
		_expanded_key = key
	_play_sfx(SFX_CARD_TAP)
	# D3: tapping a pulsing card cancels its pulse.
	if _active_pulses.has(key):
		var tw = _active_pulses[key]
		if tw != null and tw.is_valid():
			tw.kill()
		_active_pulses.erase(key)
	_build_ui()

func _build_expand_panel(it: Dictionary) -> Control:
	var category := String(it["category"])
	var item_name := String(it["name"])
	var data: Dictionary = it["data"]
	var price := int(it["price"])
	var owned := bool(it["owned"])

	var panel := PanelContainer.new()
	panel.name = "ExpandPanel_%s" % _key_for(it)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.1)
	sb.border_color = CAT_COLORS[category]["border"]
	sb.set_border_width_all(2)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	# Top row: title + collapse
	var top := HBoxContainer.new()
	var title_lbl := Label.new()
	title_lbl.text = item_name.to_upper()
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", COLOR_CREAM)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.name = "CollapseButton"
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(32, 32)
	close_btn.pressed.connect(_toggle_expand.bind(it))
	top.add_child(close_btn)
	v.add_child(top)

	# Subtitle: archetype + category
	var arch := String(it["archetype"])
	var sub := Label.new()
	if arch != "":
		sub.text = "%s • %s" % [arch, _category_display(category)]
	else:
		sub.text = _category_display(category)
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", COLOR_MUTED)
	v.add_child(sub)

	# Stats grid (2 cols)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	for k in data.keys():
		if String(k) in ["name", "archetype", "description"]:
			continue
		var s := Label.new()
		s.text = "%s: %s" % [str(k), str(data[k])]
		s.add_theme_font_size_override("font_size", 12)
		s.add_theme_color_override("font_color", COLOR_CREAM)
		grid.add_child(s)
	v.add_child(grid)

	# Description
	var desc_text: String = String(data.get("description", ""))
	if desc_text != "":
		var desc := Label.new()
		desc.text = desc_text
		desc.add_theme_font_size_override("font_size", 11)
		desc.add_theme_color_override("font_color", COLOR_MUTED)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size.x = 600
		v.add_child(desc)

	# Buy row
	var buy_row := HBoxContainer.new()
	buy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var buy := Button.new()
	buy.name = "BuyButton"
	if owned:
		buy.text = "✓ Owned"
		buy.disabled = true
	elif price > game_state.bolts:
		buy.text = "Need %d more 🔩" % (price - game_state.bolts)
		buy.disabled = true
	else:
		# D0 (F1 hotfix): ternary precedence — parenthesize the %-format operand.
		buy.text = ("BUY — %d 🔩" % price) if price > 0 else "TAKE (Free)"
		buy.pressed.connect(_on_buy.bind(category, int(it["type"])))
	buy.custom_minimum_size = Vector2(240, 40)
	buy.add_theme_font_size_override("font_size", 16)
	buy_row.add_child(buy)
	v.add_child(buy_row)

	return panel

# --- Buy ---

func _on_buy(category: String, type: int) -> void:
	var success := false
	match category:
		"weapon":  success = game_state.buy_weapon(type)
		"armor":   success = game_state.buy_armor(type)
		"chassis": success = game_state.buy_chassis(type)
		"module":  success = game_state.buy_module(type)
	if success:
		item_purchased.emit(category, type)
		# D1: success SFX + buy button scale pulse before rebuild
		_play_sfx(SFX_BUY_SUCCESS)
		var buy_button := _find_buy_button()
		if buy_button != null:
			var tween := create_tween()
			tween.tween_property(buy_button, "scale", Vector2(1.12, 1.12), 0.06)
			tween.tween_property(buy_button, "scale", Vector2(1.0, 1.0), 0.06)
			await tween.finished
		# Collapse panel after successful buy
		_expanded_key = ""
		_build_ui()
	else:
		_play_sfx(SFX_BUY_FAIL)

func _find_buy_button() -> Button:
	# BuyButton lives inside the currently-expanded ExpandPanel.
	var nodes := find_children("BuyButton", "Button", true, false)
	if nodes.size() > 0:
		return nodes[0] as Button
	return null
