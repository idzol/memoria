# [AI-CONTRACT]
# FILE: res://core/SignalBus.gd
# FEATURES: Global signal hub for decoupled communication.
# [YOLO-METADATA] TARGET: res://core/SignalBus.gd
# NOTES: This script should be added as an Autoload named 'SignalBus'

extends Node

# --- Game Flow Signals ---
signal game_started
signal game_exited
signal level_up(new_level: int)

# --- Map Signals ---
signal node_selected(node_data)
signal map_generated(map_data)
signal map_node_completed(node_id)

# --- Narrative & Identity Signals ---
signal cutscene_requested(cutscene_id: String)
signal cutscene_finished(cutscene_id: String)

# --- Combat Signals ---
signal combat_started(enemy_data)
signal combat_won
signal combat_lost
signal turn_started(is_player_turn: bool)
signal energy_changed(current: int, max_val: int)
signal card_matched(card_type)
signal player_damaged(amount)
signal enemy_damaged(amount)

# --- Progression & UI Signals ---
signal gold_changed(new_total)
signal hp_changed(current, max_hp)
signal save_requested
signal run_started
signal run_ended(is_victory)    
