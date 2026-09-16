extends RefCounted
class_name BattleLog

# A plain recorder for combat.gd's existing `event` signal — nothing here changes combat.gd
# itself; this just listens alongside game_battle_screen.gd's own animation dispatcher
# (Godot signals support multiple simultaneous connections) and keeps a structured history a
# player can review after the fight, independent of whatever toasts/animations already fired
# for the same event in the moment. Kept as plain data (kind/payload/turn), not pre-rendered
# text, so it renders correctly in whichever language is active when the player opens it later
# rather than whatever language was active during the fight itself.
var entries: Array = []

func record(kind: String, payload: Dictionary, turn: int) -> void:
	entries.append({"turn": turn, "kind": kind, "payload": payload.duplicate(true)})
