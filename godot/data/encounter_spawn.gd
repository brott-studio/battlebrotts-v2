## encounter_spawn.gd — S25.7: Canonical enemy spawn position table.
class_name EncounterSpawn
extends RefCounted

## Returns N enemy spawn positions on the right half of the arena.
## Player spawns at (4*32, 8*32) — left half. Enemies use right half.
static func positions_for(n: int) -> Array[Vector2]:
	if n <= 0:
		return []
	match n:
		1: return [Vector2(12 * 32.0, 8 * 32.0)]
		2: return [Vector2(10 * 32.0, 8 * 32.0), Vector2(14 * 32.0, 8 * 32.0)]
		3: return [Vector2(10 * 32.0, 6 * 32.0), Vector2(14 * 32.0, 6 * 32.0), Vector2(12 * 32.0, 11 * 32.0)]
		4: return [Vector2(9 * 32.0, 6 * 32.0), Vector2(13 * 32.0, 6 * 32.0),
				   Vector2(9 * 32.0, 10 * 32.0), Vector2(13 * 32.0, 10 * 32.0)]
		_:  ## 5+: 2-column grid on right half
			var positions: Array[Vector2] = []
			var cols := 2
			for i in range(n):
				var col := i % cols
				var row := i / cols
				var x := (10 + col * 4) * 32.0
				var y := (4 + row * 3) * 32.0
				positions.append(Vector2(x, y))
			return positions
