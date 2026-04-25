## run_complete_screen.gd — S25.8: Full victory screen with build summary + stats.
## GDD §A.5: single "New Run" button; no "Return to Menu".
class_name RunCompleteScreen
extends Control

signal new_run_pressed

func setup(run_state: RunState) -> void:
	_build_ui(run_state)

func _build_ui(rs: RunState) -> void:
	## Header
	var title := Label.new()
	title.text = "🏆 RUN COMPLETE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.position = Vector2(290, 60)
	title.size = Vector2(700, 65)
	add_child(title)

	var boss_lbl := Label.new()
	boss_lbl.text = "Boss Defeated: CEO Brott"
	boss_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_lbl.add_theme_font_size_override("font_size", 18)
	boss_lbl.position = Vector2(340, 135)
	boss_lbl.size = Vector2(600, 30)
	add_child(boss_lbl)

	## --- YOUR BUILD --- (inline build summary — identical structure to BrottDownScreen)
	## TODO(S25.9+): extract to BuildSummaryComponent — also reused by reward pick header.
	var build_hdr := Label.new()
	build_hdr.name = "BuildHeader"
	build_hdr.text = "YOUR BUILD"
	build_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build_hdr.add_theme_font_size_override("font_size", 14)
	build_hdr.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	build_hdr.position = Vector2(390, 180)
	build_hdr.size = Vector2(500, 24)
	add_child(build_hdr)

	var chassis_names := ["Scout", "Brawler", "Fortress"]
	var chassis_lbl := Label.new()
	chassis_lbl.name = "ChassisLabel"
	chassis_lbl.text = "⚙ %s" % (chassis_names[rs.equipped_chassis] if rs.equipped_chassis < chassis_names.size() else "Unknown")
	chassis_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chassis_lbl.add_theme_font_size_override("font_size", 16)
	chassis_lbl.position = Vector2(390, 208)
	chassis_lbl.size = Vector2(500, 26)
	add_child(chassis_lbl)

	## Weapons row
	var weapon_names := ["Minigun", "Railgun", "Shotgun", "Missile Pod", "Plasma Cutter", "Arc Emitter", "Flak Cannon"]
	var weapons_text := " | ".join(rs.equipped_weapons.map(func(w): return weapon_names[w] if w < weapon_names.size() else "?"))
	var weapons_lbl := Label.new()
	weapons_lbl.name = "WeaponsLabel"
	weapons_lbl.text = "⚡ %s" % (weapons_text if weapons_text != "" else "—")
	weapons_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapons_lbl.add_theme_font_size_override("font_size", 13)
	weapons_lbl.position = Vector2(340, 236)
	weapons_lbl.size = Vector2(600, 22)
	add_child(weapons_lbl)

	## Armor
	var armor_names := ["None", "Plating", "Reactive Mesh", "Ablative Shell"]
	var armor_lbl := Label.new()
	armor_lbl.name = "ArmorLabel"
	armor_lbl.text = "🛡 %s" % (armor_names[rs.equipped_armor] if rs.equipped_armor < armor_names.size() else "None")
	armor_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	armor_lbl.add_theme_font_size_override("font_size", 13)
	armor_lbl.position = Vector2(340, 260)
	armor_lbl.size = Vector2(600, 22)
	add_child(armor_lbl)

	## Modules row
	var module_names := ["Overclock", "Repair Nanites", "Shield Projector", "Sensor Array", "Afterburner", "EMP Charge"]
	var mods_text := " | ".join(rs.equipped_modules.map(func(m): return module_names[m] if m < module_names.size() else "?"))
	var modules_lbl := Label.new()
	modules_lbl.name = "ModulesLabel"
	modules_lbl.text = "🔩 %s" % (mods_text if mods_text != "" else "—")
	modules_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modules_lbl.add_theme_font_size_override("font_size", 13)
	modules_lbl.position = Vector2(340, 284)
	modules_lbl.size = Vector2(600, 22)
	add_child(modules_lbl)

	## Stats block
	var stats_lbl := Label.new()
	stats_lbl.name = "StatsLabel"
	stats_lbl.text = "Battles Won: 15 / 15    Retries Used: %d / 3    Best Kill: —" % max(0, 3 - rs.retry_count)
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.add_theme_font_size_override("font_size", 15)
	stats_lbl.position = Vector2(290, 326)
	stats_lbl.size = Vector2(700, 28)
	add_child(stats_lbl)

	## New Run button (no "Return to Menu" — GDD §A.5)
	var btn := Button.new()
	btn.name = "NewRunButton"
	btn.text = "⚡ New Run"
	btn.position = Vector2(465, 390)
	btn.size = Vector2(350, 60)
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(func(): new_run_pressed.emit())
	add_child(btn)
