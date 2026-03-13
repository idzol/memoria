extends Node

const TRANSLATION_CSV_PATH = "res://data/localization/text.csv"
const SETTINGS_PATH = "user://settings.cfg"
const SETTINGS_SECTION = "localization"
const SETTINGS_KEY = "language"
const DEFAULT_LANGUAGE = "en"
const SUPPORTED_LANGUAGES = ["en", "es", "fr", "de"]
const LANGUAGE_LABEL_KEYS = {
	"en": "language.english",
	"es": "language.spanish",
	"fr": "language.french",
	"de": "language.german"
}

var current_language: String = DEFAULT_LANGUAGE
var _translations: Dictionary = {}

func _ready():
	_load_translations()
	_load_language_setting()

func translate(key: String, fallback: String = "") -> String:
	if key == "":
		return fallback
	var entry = _translations.get(key, {})
	if entry.has(current_language):
		return str(entry[current_language])
	if entry.has(DEFAULT_LANGUAGE):
		return str(entry[DEFAULT_LANGUAGE])
	return fallback if fallback != "" else key

func set_language(language_code: String):
	if not SUPPORTED_LANGUAGES.has(language_code):
		return
	current_language = language_code
	_save_language_setting()

func cycle_language() -> String:
	var current_index = SUPPORTED_LANGUAGES.find(current_language)
	if current_index == -1:
		current_index = 0
	var next_index = (current_index + 1) % SUPPORTED_LANGUAGES.size()
	set_language(SUPPORTED_LANGUAGES[next_index])
	return current_language

func get_language_display_name(language_code: String = current_language) -> String:
	var key = str(LANGUAGE_LABEL_KEYS.get(language_code, ""))
	if key == "":
		return language_code.to_upper()
	return translate(key, language_code.to_upper())

func _load_translations():
	_translations.clear()
	if not FileAccess.file_exists(TRANSLATION_CSV_PATH):
		push_warning("LocalizationManager: Missing translation csv at %s" % TRANSLATION_CSV_PATH)
		return
	var file = FileAccess.open(TRANSLATION_CSV_PATH, FileAccess.READ)
	if not file:
		return
	var is_header := true
	while not file.eof_reached():
		var row = file.get_csv_line()
		if row.is_empty():
			continue
		if is_header:
			is_header = false
			continue
		if row.size() < 5:
			continue
		var key = str(row[0]).strip_edges()
		if key == "":
			continue
		_translations[key] = {
			"en": str(row[1]),
			"es": str(row[2]),
			"fr": str(row[3]),
			"de": str(row[4])
		}

func _load_language_setting():
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		current_language = DEFAULT_LANGUAGE
		return
	var saved_language = str(config.get_value(SETTINGS_SECTION, SETTINGS_KEY, DEFAULT_LANGUAGE))
	current_language = saved_language if SUPPORTED_LANGUAGES.has(saved_language) else DEFAULT_LANGUAGE

func _save_language_setting():
	var config = ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(SETTINGS_SECTION, SETTINGS_KEY, current_language)
	config.save(SETTINGS_PATH)
