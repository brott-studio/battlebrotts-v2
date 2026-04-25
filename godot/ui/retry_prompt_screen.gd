## retry_prompt_screen.gd — S25.5: Post-loss retry / accept loss screen.
class_name RetryPromptScreen
extends Control

signal retry_chosen
signal accept_loss

var _run_state: RunState = null

func setup(run_state: RunState) -> void:
	_run_state = run_state
	var hud := RunHudBar.new()
	hud.size = Vector2(1280, 36)
	hud.position = Vector2(0, 0)
	add_child(hud)
	hud.setup(run_state)
	_build_ui()

func _build_ui() -> void:
	var title := Label.new()
	title.text = "💀 BROTT DOWN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	title.position = Vector2(390, 80)
	title.size = Vector2(500, 60)
	add_child(title)

	var sub := Label.new()
	sub.text = "Retries remaining: %d" % _run_state.retry_count
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.position = Vector2(390, 160)
	sub.size = Vector2(500, 40)
	add_child(sub)

	if _run_state.retry_count > 0:
		var retry_btn := Button.new()
		retry_btn.text = "↩ Retry Battle"
		retry_btn.position = Vector2(390, 240)
		retry_btn.size = Vector2(230, 60)
		retry_btn.add_theme_font_size_override("font_size", 20)
		retry_btn.pressed.connect(_on_retry_pressed)
		add_child(retry_btn)

		var loss_btn := Button.new()
		loss_btn.text = "✗ Accept Loss"
		loss_btn.position = Vector2(660, 240)
		loss_btn.size = Vector2(230, 60)
		loss_btn.add_theme_font_size_override("font_size", 20)
		loss_btn.pressed.connect(func(): accept_loss.emit())
		add_child(loss_btn)
	else:
		var loss_btn := Button.new()
		loss_btn.text = "✗ Accept Loss"
		loss_btn.position = Vector2(515, 240)
		loss_btn.size = Vector2(250, 60)
		loss_btn.add_theme_font_size_override("font_size", 20)
		loss_btn.pressed.connect(func(): accept_loss.emit())
		add_child(loss_btn)

func _on_retry_pressed() -> void:
	_run_state.use_retry()
	## Regenerate arena seed using post-decrement retry_count
	var new_seed := _run_state.seed * 31 + _run_state.current_battle_index * 1000 + _run_state.retry_count
	_run_state.current_encounter["arena_seed"] = new_seed
	retry_chosen.emit()
