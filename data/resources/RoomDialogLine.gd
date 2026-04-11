extends Resource
class_name RoomDialogLine

@export_enum("player", "npc", "enemy", "narrator") var speaker_role: String = "narrator"
@export var speaker_name_key: String = ""
@export var speaker_name: String = ""
@export var text_key: String = ""
@export_multiline var text: String = ""
