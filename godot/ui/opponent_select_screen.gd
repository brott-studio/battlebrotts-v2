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
	
	var opponents := OpponentData.get_league_opponents(game_state.current_league)
	var y := 80
	
	for i in range(opponents.size()):
		var opp: Dictionary = opponents[i]
		var opp_id: String = "%s_%d" % [game_state.current_league, i]
		var beaten: bool = opp_id in game_state.opponents_beaten
		
		var panel := Panel.new()
		panel.position = Vector2(40, y)
		panel.size = Vector2(700, 120)
		add_child(panel)
		
		# Name
		var name_lbl := Label.new()
		name_lbl.text = ("✅ " if beaten else "⚔️ ") + opp["name"]
		name_lbl.add_theme_font_size_override("font_size", 22)
		name_lbl.position = Vector2(60, y + 10)
		name_lbl.size = Vector2(400, 30)
		add_child(name_lbl)
		
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
		add_child(info_lbl)
		
		# Fight button
		var btn := Button.new()
		btn.text = "FIGHT!" if not beaten else "REMATCH"
		btn.position = Vector2(560, y + 70)
		btn.size = Vector2(150, 35)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(func(): opponent_selected.emit(i))
		add_child(btn)
		
		y += 140
	
	# Back button
	var back_btn := Button.new()
	back_btn.text = "← Back"
	back_btn.position = Vector2(20, 650)
	back_btn.size = Vector2(150, 50)
	back_btn.pressed.connect(func(): back_pressed.emit())
	add_child(back_btn)
