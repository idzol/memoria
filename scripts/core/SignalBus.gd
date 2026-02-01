extends Node

# Global Signal Bus for Memory Dungeon
# This script should be added as an Autoload named 'SignalBus'

# --- Map Signals ---
signal node_selected(node_data)
signal map_generated(map_data)
signal map_node_completed(node_id)

# --- Combat Signals ---
signal combat_started(enemy_data)
signal combat_won
signal combat_lost
signal card_matched(card_type)
signal player_damaged(amount)
signal enemy_damaged(amount)

# --- Progression & UI Signals ---
signal gold_changed(new_total)
signal hp_changed(current, max_hp)
signal save_requested
signal run_started
signal run_ended(is_victory)    