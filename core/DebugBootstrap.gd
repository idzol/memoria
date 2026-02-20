extends Node

# res://core/DebugBootstrapper.gd
# Usage: Set this as the Main Scene temporarily to test specific states.

func _ready():
	# Wait for Autoloads to initialize
	await get_tree().process_frame
	
	# TEST CASE 1: Mid-game Archivist in the Abyss
	# setup_mid_game_test("Archivist", 5, 45, ["sword", "frost", "bomb"])
	
	# TEST CASE 2: Low HP Berserker at a Boss
	setup_boss_test("Berserker", 10, ["axe", "trap", "block"])

func setup_mid_game_test(p_class: String, gold: int, hp: int, deck: Array):
	print("[DEBUG] Bootstrapping Mid-Game Test...")
	GameManager.player_class = p_class
	GameManager.gold = gold
	GameManager.current_hp = hp
	GameManager.active_deck = deck
	GameManager.player_inventory = deck.duplicate()
	GameManager.current_level = 10
	
	# Manually set a target node to simulate map selection
	GameManager.current_node = {
		"id": "99",
		"type": "battle",
		"difficulty": 4,
		"biome": "ice_caves",
		"room_resource_path": "res://data/rooms/ice_caves/i1.tres"
	}
	
	get_tree().change_scene_to_file("res://features/combat/BattleScene.tscn")

func setup_boss_test(p_class: String, hp: int, deck: Array):
	print("[DEBUG] Bootstrapping Boss Test...")
	GameManager.player_class = p_class
	GameManager.current_hp = hp
	GameManager.active_deck = deck
	
	GameManager.current_node = {
		"id": "boss_final",
		"type": "boss",
		"difficulty": 6,
		"biome": "void",
		"room_resource_path": "res://data/rooms/void/v20.tres"
	}
	
	get_tree().change_scene_to_file("res://features/combat/BattleScene.tscn")