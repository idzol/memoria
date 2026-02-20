extends "res://addons/gut/test.gd"

# res://test/unit/test_game_systems.gd
# Tests GameManager state, inventory limits, and save/load integrity.

func before_each():
	# Clear GameManager state
	GameManager.player_name = "TestHero"
	GameManager.completed_nodes = []
	GameManager.current_hp = 100

func test_run_initialization():
	GameManager.start_actual_run()
	assert_eq(GameManager.current_level, 1, "New run should start at level 1")
	assert_gt(GameManager.active_deck.size(), 2, "New run should have a starting deck")
	assert_eq(GameManager.player_grid_pos, Vector2i(2, -1), "Should start at home coords")

func test_combat_win_persistence():
	var initial_gold = GameManager.gold
	GameManager.current_node = {"id": "test_node_1"}
	
	SignalBus.combat_won.emit()
	
	assert_eq(GameManager.gold, initial_gold + 25, "Winning combat should grant gold")
	assert_has(GameManager.completed_nodes, "test_node_1", "Node should be marked completed")

func test_save_load_roundtrip():
	GameManager.player_name = "SaveTester"
	GameManager.gold = 999
	SaveManager.save_mid_run_state()
	
	# Verify file exists
	var path = "user://saves/run_SaveTester.json"
	assert_file_exists(path)
	
	# Modify and reload
	GameManager.gold = 0
	var saves = SaveManager.get_save_list()
	var my_save = null
	for s in saves:
		if s.player_name == "SaveTester":
			my_save = s
			break
	
	assert_not_null(my_save, "Save file should be found in list")
	GameManager.load_run_from_data(my_save)
	assert_eq(GameManager.gold, 999, "Reloaded data should restore gold stat")