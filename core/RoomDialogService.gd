extends RefCounted
class_name RoomDialogService

const SPEAKER_COLOR_PLAYER := Color(0.45, 0.68, 1.0, 1.0)
const SPEAKER_COLOR_ENEMY := Color(1.0, 0.42, 0.42, 1.0)
const SPEAKER_COLOR_NPC := Color(0.46, 0.9, 0.52, 1.0)
const SPEAKER_COLOR_NARRATOR := Color(0.96, 0.96, 0.96, 1.0)

static func resolve_room_dialog(room_res: RoomData, node_data: Dictionary, npc_res: NPCData = null) -> Array[Dictionary]:
	if room_res == null or room_res.dialogue == null:
		return []
	var enemy_res := _load_enemy_resource(room_res.enemy_id)
	var context = {
		"id": str(node_data.get("id", "")),
		"biome": room_res.biome,
		"enemy_id": room_res.enemy_id,
		"npc_id": room_res.npc_id
	}
	for sequence in room_res.dialogue.sequences:
		if sequence == null:
			continue
		if not sequence.condition.is_empty() and not GameManager.evaluate_condition(sequence.condition, context):
			continue
		var resolved_lines: Array[Dictionary] = []
		for line in sequence.lines:
			if line == null:
				continue
			resolved_lines.append({
				"speaker_role": line.speaker_role,
				"speaker_name": _resolve_speaker_name(line, room_res, npc_res, enemy_res),
				"speaker_color": _resolve_speaker_color(line.speaker_role),
				"text": LocalizationManager.translate(line.text_key, line.text)
			})
		if not resolved_lines.is_empty():
			return resolved_lines
	return []

static func _resolve_speaker_name(line: RoomDialogLine, room_res: RoomData, npc_res: NPCData = null, enemy_res: EnemyData = null) -> String:
	if line.speaker_name_key != "":
		return LocalizationManager.translate(line.speaker_name_key, line.speaker_name)
	if line.speaker_name != "":
		return line.speaker_name
	match line.speaker_role:
		"player":
			if GameManager.player_name != "":
				return GameManager.player_name
			return LocalizationManager.translate("dialog.speaker.player", "You")
		"npc":
			if npc_res != null and npc_res.name != "":
				return npc_res.name
			return LocalizationManager.translate("dialog.speaker.npc", "NPC")
		"enemy":
			if enemy_res != null and enemy_res.name != "":
				return enemy_res.name
			return LocalizationManager.translate("dialog.speaker.enemy", "Enemy")
		_:
			return LocalizationManager.translate("dialog.speaker.narrator", room_res.room_name if room_res != null else "Narrator")

static func _load_enemy_resource(enemy_id: String) -> EnemyData:
	if enemy_id == "":
		return null
	var enemy_path = "res://data/enemies/%s.tres" % enemy_id
	if not ResourceLoader.exists(enemy_path):
		return null
	return load(enemy_path) as EnemyData

static func _resolve_speaker_color(speaker_role: String) -> Color:
	match speaker_role:
		"player":
			return SPEAKER_COLOR_PLAYER
		"npc":
			return SPEAKER_COLOR_NPC
		"enemy":
			return SPEAKER_COLOR_ENEMY
		_:
			return SPEAKER_COLOR_NARRATOR
