## Result screen — win/loss, Bolts earned, repair cost
class_name ResultScreen
extends Control

signal continue_pressed
signal rematch_pressed

var won: bool = false
var bolts_earned: int = 0
var game_state: GameState

func setup(state: GameState, match_won: bool, earned: int) -> void:
	game_state = state
	won = match_won
	bolts_earned = earned
	_build_ui()

func _build_ui() -> void:
	for c in get_children():
		c.queue_free()
	
	# Result banner
	var banner := Label.new()
	banner.text = "🏆 VICTORY!" if won else "💀 DEFEAT"
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 48)
	if won:
		banner.add_theme_color_override("font_color", Color.GOLD)
	else:
		banner.add_theme_color_override("font_color", Color.RED)
	banner.position = Vector2(340, 100)
	banner.size = Vector2(600, 80)
	add_child(banner)
	
	# Bolts info
	var repair := 20 if won else 50
	var gross := bolts_earned + repair
	
	var info := Label.new()
	info.text = "Bolts earned: %d 🔩\nRepair cost: -%d 🔩\nNet: %d 🔩\n\nTotal Bolts: %d 🔩" % [
		gross, repair, bolts_earned, game_state.bolts
	]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 20)
	info.position = Vector2(440, 220)
	info.size = Vector2(400, 200)
	add_child(info)
	
	# [S21.2 / #103 #6] League progress caption — plain-language progress meter
	# beneath the bolts info. Visible by default, no hover. Surfaces league +
	# beat count + remaining count or unlock-pending state.
	var progress := Label.new()
	progress.name = "league_progress_caption"
	progress.text = _progress_caption_text()
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress.add_theme_font_size_override("font_size", 13)
	progress.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	progress.position = Vector2(390, 380)
	progress.size = Vector2(500, 30)
	add_child(progress)

	# [S21.4 / #108] NextLeaguePathIndicator — post-match league progression
	# surfacing. Visible only when the just-completed match was the league
	# final win (bronze_unlocked edge). Shows the next-league path to the
	# player immediately on the result screen, before the ceremony modal.
	var next_league := Label.new()
	next_league.name = "NextLeaguePathIndicator"
	next_league.text = _next_league_path_text()
	next_league.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_league.add_theme_font_size_override("font_size", 16)
	next_league.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	next_league.position = Vector2(390, 418)
	next_league.size = Vector2(500, 30)
	next_league.visible = game_state != null and game_state.bronze_unlocked
	add_child(next_league)
	
	# Bronze unlock message
	if game_state.bronze_unlocked and game_state.brottbrain_unlocked:
		var unlock := Label.new()
		unlock.text = "🧠 BrottBrain Editor UNLOCKED!\nNew items available in the shop!"
		unlock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		unlock.add_theme_font_size_override("font_size", 18)
		unlock.add_theme_color_override("font_color", Color.CYAN)
		unlock.position = Vector2(390, 420)
		unlock.size = Vector2(500, 60)
		add_child(unlock)
	
	# Buttons
	var rematch_btn := Button.new()
	rematch_btn.text = "🔄 Rematch"
	rematch_btn.position = Vector2(440, 530)
	rematch_btn.size = Vector2(180, 50)
	rematch_btn.add_theme_font_size_override("font_size", 18)
	rematch_btn.pressed.connect(func(): rematch_pressed.emit())
	add_child(rematch_btn)
	
	var cont_btn := Button.new()
	cont_btn.text = "Continue →"
	cont_btn.position = Vector2(660, 530)
	cont_btn.size = Vector2(180, 50)
	cont_btn.add_theme_font_size_override("font_size", 18)
	cont_btn.pressed.connect(func(): continue_pressed.emit())
	add_child(cont_btn)

# [S21.2 / #103 #6] League-progress caption text. Counts opponents beaten in
# the current league and reports remaining unlocks; mentions BrottBrain
# unlock-pending when the bronze gate is one win away.
# [S21.4 / #108] Next-league path text for NextLeaguePathIndicator.
# Returns the display text for the next league after a final-win unlock.
# Minimal copy — uses league name if available in progression chain.
func _next_league_path_text() -> String:
	if game_state == null or not game_state.bronze_unlocked:
		return ""
	# Scrapyard final win unlocks Bronze — show the next path.
	if game_state.current_league == "scrapyard" or game_state.current_league == "bronze":
		return "🏅 Next League: Bronze"
	return ""

func _progress_caption_text() -> String:
	if game_state == null:
		return ""
	var league: String = game_state.current_league
	var opponents: Array = OpponentData.get_league_opponents(league)
	var total: int = opponents.size()
	var beat: int = 0
	for opp in opponents:
		if String(opp.get("id", "")) in game_state.opponents_beaten:
			beat += 1
	var remaining: int = max(total - beat, 0)
	var suffix: String = ""
	if league == "scrapyard" and not game_state.bronze_unlocked:
		if remaining == 0:
			suffix = " — Bronze League ready to unlock."
		elif remaining == 1:
			suffix = " — 1 win to Bronze + BrottBrain."
		else:
			suffix = " — %d wins to Bronze." % remaining
	return "%s League: %d/%d opponents beaten.%s" % [league.capitalize(), beat, total, suffix]
