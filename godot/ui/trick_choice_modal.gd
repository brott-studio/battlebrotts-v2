extends CanvasLayer

signal resolved(trick_id: String, choice_key: String)

@onready var _overlay: ColorRect = $Overlay
@onready var _dialogue: Label = $Overlay/Panel/VBox/TopRow/Dialogue
@onready var _prompt: Label = $Overlay/Panel/VBox/Prompt
@onready var _btn_a: Button = $Overlay/Panel/VBox/Buttons/ChoiceA
@onready var _btn_b: Button = $Overlay/Panel/VBox/Buttons/ChoiceB
@onready var _toast: Label = $Overlay/Toast
var _trick: Dictionary = {}

func show_trick(trick: Dictionary) -> void:
	_trick = trick
	_dialogue.text = trick["brottbrain_text"]
	_prompt.text = trick["prompt"]
	_btn_a.text = trick["choice_a"]["label"]
	_btn_b.text = trick["choice_b"]["label"]
	_toast.visible = false
	_overlay.modulate.a = 0.0
	_btn_a.pressed.connect(func(): _on_choice("choice_a"))
	_btn_b.pressed.connect(func(): _on_choice("choice_b"))
	create_tween().tween_property(_overlay, "modulate:a", 1.0, 0.2)

func _on_choice(key: String) -> void:
	_btn_a.disabled = true
	_btn_b.disabled = true
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
