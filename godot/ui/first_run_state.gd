## [S17.1-004] First-run persistence helper — shared with S17.1-006.
##
## Autoload singleton registered in project.godot as `FirstRunState`.
## Backs a flat ConfigFile at `user://first_run.cfg` with a single
## `[seen]` section of boolean flags. See design doc §5 for API shape
## and reserved keys.
##
## Consumers:
##   - S17.1-004 first-encounter energy overlay → key `energy_explainer`
##   - S17.1-006 first-run crate popup (reserved) → key `crate_first_run`
##
## Add new keys by writing a new flag string; no code change required
## here. Do not reuse or rename existing keys — old saves carry them.
class_name FirstRunStateClass
extends Node

const STORE_PATH := "user://first_run.cfg"
const SECTION := "seen"

var _cfg: ConfigFile = ConfigFile.new()
var _loaded: bool = false

func _ensure_loaded() -> void:
	if _loaded:
		return
	var err := _cfg.load(STORE_PATH)
	# OK or ERR_FILE_NOT_FOUND are both fine; any other error we log and
	# treat as fresh (the broken file will be overwritten on the next save).
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("[FirstRunState] load error %s — treating as fresh" % err)
		_cfg = ConfigFile.new()
	_loaded = true

func has_seen(key: String) -> bool:
	_ensure_loaded()
	return bool(_cfg.get_value(SECTION, key, false))

func mark_seen(key: String) -> void:
	_ensure_loaded()
	_cfg.set_value(SECTION, key, true)
	var err := _cfg.save(STORE_PATH)
	if err != OK:
		push_warning("[FirstRunState] save error %s for key=%s" % [err, key])

# Dev/test use only — not called from gameplay.
func reset(key: String) -> void:
	_ensure_loaded()
	_cfg.set_value(SECTION, key, false)
	_cfg.save(STORE_PATH)
