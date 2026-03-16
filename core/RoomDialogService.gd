extends RefCounted
class_name RoomDialogService

static func resolve_room_dialog(room_res: RoomData, node_data: Dictionary, npc_res: NPCData = null) -> Array[Dictionary]:
	if room_res == null or room_res.dialogue == null:
		return []
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
				"speaker_name": _resolve_speaker_name(line, room_res, npc_res),
				"text": LocalizationManager.translate(line.text_key, line.text)
			})
		if not resolved_lines.is_empty():
			return resolved_lines
	return []

static func _resolve_speaker_name(line: RoomDialogLine, room_res: RoomData, npc_res: NPCData = null) -> String:
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
		_:
			return LocalizationManager.translate("dialog.speaker.narrator", room_res.room_name if room_res != null else "Narrator")
