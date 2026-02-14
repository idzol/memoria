extends Node

# res://scripts/logic/CombatManager.gd
# Handles combat math, enemy behavior patterns, and stat scaling.

# IMPORT: Centralized enemy data from GameData.gd
const GameData = preload("res://scripts/data/GameData.gd")

# --- Combat State ---
var player_hp: int = 100
var player_max_hp: int = 100
var enemy_hp: int = 50
var enemy_armor: int = 0
var enemy_magic_resist: int = 0
var enemy_intent: String = "ATTACK"
var current_enemy_id: String = "pickpocket"
var current_difficulty: int = 0

func _ready():
	SignalBus.card_matched.connect(_on_card_matched)
	player_hp = GameManager.current_hp
	player_max_hp = GameManager.max_hp
	current_difficulty = GameManager.current_node.get("difficulty", 0)
	
	# Determine which enemy to spawn (could be based on biome/difficulty)
	current_enemy_id = "pickpocket" if current_difficulty < 3 else "slime"
	_setup_enemy(current_enemy_id, current_difficulty)

func _setup_enemy(enemy_id: String, diff: int):
	# Accessing ENEMIES through the GameData reference
	var data = GameData.ENEMIES.get(enemy_id, GameData.ENEMIES["pickpocket"])
	
	# Scale HP and Resistances based on floor difficulty
	enemy_hp = data.hp + (diff * 15)
	enemy_armor = data.armor + diff
	enemy_magic_resist = data.magic_resist + diff
	
	_generate_next_intent()
	SignalBus.hp_changed.emit(player_hp, player_max_hp)

func _on_card_matched(type: String):
	var card = CardDatabase.get_card(type)
	var stats = card.stats
	
	# Determine damage type (Magical vs Physical)
	var is_magical = type in ["lightning", "frost", "bomb", "scroll"]
	
	if stats.damage > 0:
		var raw_dmg = stats.damage + (current_difficulty * 2)
		_damage_enemy(raw_dmg, is_magical)
		
	if stats.heal > 0:
		_heal_player(stats.heal)
		
	if stats.trap > 0:
		_damage_player(stats.trap)
	
	_check_victory()

func _damage_enemy(amount: int, is_magical: bool):
	# Calculate damage reduction based on enemy stats
	var reduction = enemy_magic_resist if is_magical else enemy_armor
	var final_dmg = max(1, amount - reduction)
	
	enemy_hp = max(0, enemy_hp - final_dmg)
	SignalBus.enemy_damaged.emit(final_dmg)

func _heal_player(amount: int):
	player_hp = min(player_max_hp, player_hp + amount)
	GameManager.current_hp = player_hp
	SignalBus.hp_changed.emit(player_hp, player_max_hp)

func _damage_player(amount: int):
	player_hp = max(0, player_hp - amount)
	GameManager.current_hp = player_hp
	SignalBus.hp_changed.emit(player_hp, player_max_hp)
	if player_hp <= 0: SignalBus.combat_lost.emit()

func _check_victory():
	if enemy_hp <= 0: SignalBus.combat_won.emit()

func _generate_next_intent():
	# Accessing ENEMIES through the GameData reference
	var data = GameData.ENEMIES.get(current_enemy_id, GameData.ENEMIES["pickpocket"])
	var probs = data.probabilities # [Attack, Strong, Debuff, Pass]
	
	var roll = randf()
	if roll < probs[0]:
		enemy_intent = "ATTACK"
	elif roll < probs[0] + probs[1]:
		enemy_intent = "STRONGER_ATTACK"
	elif roll < probs[0] + probs[1] + probs[2]:
		enemy_intent = "DEBUFF"
	else:
		enemy_intent = "PASS"

func execute_enemy_turn():
	# Accessing ENEMIES through the GameData reference
	var data = GameData.ENEMIES.get(current_enemy_id, GameData.ENEMIES["pickpocket"])
	
	match enemy_intent:
		"ATTACK":
			_damage_player(data.attack + current_difficulty)
			print("Critical attack!")
		"STRONGER_ATTACK":
			_damage_player(int(data.attack * 1.5) + current_difficulty)
			print("Critical attack!")
		"DEBUFF":
			# Placeholder for status effects
			print("Enemy uses a debuff!")
		"PASS":
			print("Enemy hesitates...")
	
	_generate_next_intent()