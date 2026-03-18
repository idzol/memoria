extends RefCounted

const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION_AUDIO := "audio"

const DEFAULT_MASTER_VOLUME := 1.0
const DEFAULT_MUSIC_VOLUME := 1.0
const DEFAULT_SFX_VOLUME := 0.4

static func get_default_audio_settings() -> Dictionary:
	return {
		"master_volume": DEFAULT_MASTER_VOLUME,
		"music_volume": DEFAULT_MUSIC_VOLUME,
		"sfx_volume": DEFAULT_SFX_VOLUME
	}
