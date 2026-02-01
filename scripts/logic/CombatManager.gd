extends Node

# CombatManager.gd - The central logic for a battle encounter
# res://scripts/logic/CombatManager.gd

# Combat State
var player_hp: int = 100
var player_max_hp: int = 100
var enemy_hp: int = 50
var enemy_max_hp: int = 50
var enemy_intent: String = "ATTACK"
var turn_count: int = 0

var current_difficulty: int = 0

func _ready():
	# Listen for matching events from the SignalBus
	SignalBus.card_matched.connect(_on_card_matched)
	
	# Initialize stats from GameManager
	player_hp = GameManager.current_hp
	player_max_hp = GameManager.max_hp
	
	# Scale enemy based on difficulty level (passed from Map)
	current_difficulty = GameManager.current_node.get("difficulty", 0)
	_setup_enemy(current_difficulty)

func _setup_enemy(diff: int):
	enemy_max_hp = 40 + (diff * 20)
	enemy_hp = enemy_max_hp
	_generate_next_intent()
	
	SignalBus.hp_changed.emit(player_hp, player_max_hp)
	SignalBus.enemy_damaged.emit(0) # Triggers UI update

func _on_card_matched(type: String):
	# Execute player action
	match type:
		"sword", "axe", "dagger":
			_damage_enemy(12 + (current_difficulty * 2))
		"heart", "potion":
			_heal_player(15)
		"shield", "wall":
			# Logic for block could be added here
			print("Player blocks!")
		"trap", "bomb":
			_damage_player(15)
		"lightning":
			_damage_enemy(20)
	
	_check_victory()

func _damage_enemy(amount: int):
	enemy_hp = max(0, enemy_hp - amount)
	SignalBus.enemy_damaged.emit(amount)
	print("Enemy hit for ", amount, ". Remaining: ", enemy_hp)

func _heal_player(amount: int):
	player_hp = min(player_max_hp, player_hp + amount)
	GameManager.current_hp = player_hp # Keep GameManager in sync
	SignalBus.hp_changed.emit(player_hp, player_max_hp)

func _damage_player(amount: int):
	player_hp = max(0, player_hp - amount)
	GameManager.current_hp = player_hp
	SignalBus.hp_changed.emit(player_hp, player_max_hp)
	
	if player_hp <= 0:
		SignalBus.combat_lost.emit()

func execute_enemy_turn():
	# This is called by the BattleScene when the player fails a match
	turn_count += 1
	
	match enemy_intent:
		"ATTACK":
			_damage_player(8 + current_difficulty)
		"STRONGER_ATTACK":
			_damage_player(15 + current_difficulty)
		"DEBUFF":
			print("Enemy casts a curse!")
	
	_generate_next_intent()

func _generate_next_intent():
	var roll = randf()
	if roll < 0.6: enemy_intent = "ATTACK"
	elif roll < 0.9: enemy_intent = "STRONGER_ATTACK"
	else: enemy_intent = "DEBUFF"
	# In a full UI, you'd emit a signal to show an icon above the enemy

func _check_victory():
	if enemy_hp <= 0:
		SignalBus.combat_won.emit()