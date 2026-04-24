## Opponent select screen — pick opponent from current league
class_name OpponentSelectScreen
extends Control

signal opponent_selected(index: int)
signal back_pressed

var game_state: GameState

func setup(state: GameState) -> void:
	game_state = state
	_build_ui()

func _build_ui() -> void:
	for c in get_children():
		c.queue_free()
	
	var header := Label.new()
	header.text = "⚔️ CHOOSE YOUR OPPONENT — %s League" % game_state.current_league.capitalize()
	header.add_theme_font_size_override("font_size", 28)
	header.position = Vector2(20, 10)
	header.size = Vector2(800, 40)
	add_child(header)

	# [S21.4 / #108] LeagueProgressIndicator — pre-match league-progression
	# surfacing. Visible when player is in a league-progressed state (has
	# beaten at least one full league). Anchored to OpponentSelectScreen
	# as a sibling of the header, above ListScroll, so it's always visible
	# even when the list is scrolled. Shows current league context so the
	# player sees their progression status on the pre-match surface.
	var league_prog := Label.new()
	league_prog.name = "LeagueProgressIndicator"
	league_prog.text = _league_progress_indicator_text()
	league_prog.add_theme_font_size_override("font_size", 13)
	league_prog.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	league_prog.position = Vector2(820, 18)
	league_prog.size = Vector2(440, 24)
	league_prog.visible = game_state != null and game_state.bronze_unlocked
	add_child(league_prog)
	
	var opponents := OpponentData.get_league_opponents(game_state.current_league)
	
	# [S21.2 / #104] Wrap opponent panel list in ScrollContainer mirroring the
	# S17.1-002 LoadoutScreen pattern, so high-count leagues (5–6 opponents) +
	# the S21.2 / #103 inline subtitles do not push panels into the back-button
	# at y=650. Spec from design/2026-04-23-s21.2-ux-bundle.md §Issue #104:
	#   - ListScroll position (0, 60), size (1280, 580), vertical-only.
	#   - Content sized Vector2(1260, 40 + count * 130) (panel pitch is 140 in
	#     S21.2 due to subtitle inflation; we keep 140 to match #103 below).
	#   - Back button stays sibling of ListScroll, anchored at (20, 650).
	var list_scroll := ScrollContainer.new()
	list_scroll.name = "ListScroll"
	list_scroll.position = Vector2(0, 60)
	list_scroll.size = Vector2(1280, 580)
	list_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.follow_focus = true
	add_child(list_scroll)
	
	var list_content := Control.new()
	list_content.name = "list_content"
	list_content.custom_minimum_size = Vector2(1260, max(40 + opponents.size() * 140, 0))
	list_scroll.add_child(list_content)
	
	# Panels are positioned relative to list_content; first panel at y=20
	# (was y=80 absolute, now y=20 inside the scroll which itself starts at y=60).
	var y := 20
	
	for i in range(opponents.size()):
		var opp: Dictionary = opponents[i]
		var opp_id: String = "%s_%d" % [game_state.current_league, i]
		var beaten: bool = opp_id in game_state.opponents_beaten
		
		var panel := Panel.new()
		panel.position = Vector2(40, y)
		panel.size = Vector2(700, 120)
		list_content.add_child(panel)
		
		# Name
		var name_lbl := Label.new()
		name_lbl.text = ("✅ " if beaten else "⚔️ ") + opp["name"]
		name_lbl.add_theme_font_size_override("font_size", 22)
		name_lbl.position = Vector2(60, y + 10)
		name_lbl.size = Vector2(400, 30)
		list_content.add_child(name_lbl)
		
		# Loadout info
		var ch := ChassisData.get_chassis(opp["chassis"])
		var weapons_str := ""
		for wt in opp["weapons"]:
			var wd := WeaponData.get_weapon(wt)
			if weapons_str != "":
				weapons_str += " + "
			weapons_str += wd["name"]
		
		var armor_str := "None"
		if opp["armor"] != ArmorData.ArmorType.NONE:
			armor_str = ArmorData.get_armor(opp["armor"])["name"]
		
		var info_lbl := Label.new()
		info_lbl.text = "%s | Weapons: %s | Armor: %s" % [ch["name"], weapons_str, armor_str]
		info_lbl.position = Vector2(60, y + 40)
		info_lbl.size = Vector2(600, 25)
		list_content.add_child(info_lbl)
		
		# [S21.2 / #103 #3] Inline opponent-archetype subtitle. Visible by
		# default; <=10 words; summarizes threat profile from stance + chassis.
		var subtitle := Label.new()
		subtitle.name = "opponent_subtitle_%d" % i
		subtitle.text = _opponent_subtitle(opp)
		subtitle.add_theme_font_size_override("font_size", 11)
		subtitle.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		subtitle.position = Vector2(60, y + 65)
		subtitle.size = Vector2(480, 20)
		list_content.add_child(subtitle)
		
		# Fight button
		var btn := Button.new()
		btn.text = "FIGHT!" if not beaten else "REMATCH"
		btn.position = Vector2(560, y + 70)
		btn.size = Vector2(150, 35)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(func(): opponent_selected.emit(i))
		list_content.add_child(btn)
		
		y += 140
	
	# Back button
	var back_btn := Button.new()
	back_btn.text = "← Back"
	back_btn.position = Vector2(20, 650)
	back_btn.size = Vector2(150, 50)
	back_btn.pressed.connect(func(): back_pressed.emit())
	add_child(back_btn)

# [S21.4 / #108] League progression indicator text for LeagueProgressIndicator.
# Returns display text when player is in a league-progressed state.
# Shown only when bronze_unlocked is true (at least one prior league beaten).
func _league_progress_indicator_text() -> String:
	if game_state == null or not game_state.bronze_unlocked:
		return ""
	var league: String = game_state.current_league
	return "🏅 League Progression: %s" % league.capitalize()

# [S21.2 / #103 #3] Opponent threat-profile subtitle. Reads the opp dict's
# stance + chassis to produce a <=10-word plain-language summary, kept tonally
# adjacent to STANCE_NAMES voice without copying it verbatim.
func _opponent_subtitle(opp: Dictionary) -> String:
	var stance: int = int(opp.get("stance", 0))
	var chassis: int = int(opp.get("chassis", -1))
	var stance_blurb := ""
	match stance:
		0:
			stance_blurb = "Aggressive — closes fast and brawls."
		1:
			stance_blurb = "Defensive — holds ground, trades carefully."
		2:
			stance_blurb = "Kiting — keeps distance, chips you down."
		3:
			stance_blurb = "Ambush — waits for you to come close."
		_:
			stance_blurb = "Unknown stance."
	var chassis_blurb := ""
	if chassis == ChassisData.ChassisType.SCOUT:
		chassis_blurb = " Light frame."
	elif chassis == ChassisData.ChassisType.BRAWLER:
		chassis_blurb = " Heavy frame."
	return stance_blurb + chassis_blurb
