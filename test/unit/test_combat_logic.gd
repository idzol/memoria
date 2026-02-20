extends "res://addons/gut/test.gd"

# res://test/unit/test_combat_logic.gd
# Tests the core math and state transitions of the Battle system.

var CombatManager = load("res://features/combat/CombatManager.gd")
var _cm = null

func before_each():
	_cm = CombatManager.new()
	# We must add it to the tree because it likely uses signals/timers
	add_child(_cm)

func after_each():
	_cm.free()

func test_initial_enemy_setup():
	# Test that enemy scales correctly with difficulty
	_cm._setup_enemy("pickpocket", 0)
	assert_eq(_cm.enemy_hp, 40, "Base pickpocket HP should be 40 at diff 0")
	
	_cm._setup_enemy("pickpocket", 2)
	assert_eq(_cm.enemy_hp, 80, "Pickpocket HP should scale to 80 at diff 2 (40 + 2*20)")

func test_player_healing_logic():
	_cm.player_max_hp = 100
	_cm.player_hp = 50
	_cm._heal_player(30)
	assert_eq(_cm.player_hp, 80, "Healing should add to current HP")
	
	_cm._heal_player(50)
	assert_eq(_cm.player_hp, 100, "Healing should cap at max_hp")

func test_card_match_resolution():
	# Mocking a sword match
	_cm.enemy_hp = 100
	_cm.current_difficulty = 0
	_cm._on_card_matched("sword")
	
	# Sword deals 12 + (diff*2) = 12 damage
	assert_eq(_cm.enemy_hp, 88, "Sword match should damage enemy correctly")

func test_trap_match_penalty():
	_cm.player_hp = 100
	_cm._on_card_matched("trap")
	assert_eq(_cm.player_hp, 85, "Trap match should deal 15 damage to player")

func test_enemy_intent_generation():
	# Ensure the random intent is always one of the valid strings
	var valid_intents = ["ATTACK", "STRONGER_ATTACK", "DEBUFF"]
	for i in range(20): # Run multiple times to check randomness
		_cm._generate_next_intent()
		assert_has(valid_intents, _cm.enemy_intent, "Intent must be valid")

func test_victory_signal():
	watch_signals(SignalBus)
	_cm.enemy_hp = 5
	_cm._damage_enemy(10)
	assert_signal_emitted(SignalBus, "combat_won", "Reducing enemy HP to 0 emits combat_won")

func test_defeat_signal():
	watch_signals(SignalBus)
	_cm.player_hp = 5
	_cm._damage_player(10)
	assert_signal_emitted(SignalBus, "combat_lost", "Losing all HP should emit combat_lost")