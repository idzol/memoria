class_name GameData
extends Node

# [AI-CONTRACT]
# FILE: res://core/GameData.gd
# FEATURES: Global constants for character statistics and progression balancing.
# [YOLO-METADATA] TARGET: res://core/GameData.gd

# [UI-107] Centralized Class Statistics Progression
# Defines stat blocks for 8 levels per class with exaggerated archetypes.
const CLASS_STATS = {
	"warrior": [
		{"max_hp": 25, "energy": 2, "player_attack": 5, "player_defense": 3}, # Lv 1: Brute start
		{"max_hp": 40, "energy": 2, "player_attack": 8, "player_defense": 5}, # Lv 2
		{"max_hp": 65, "energy": 3, "player_attack": 12, "player_defense": 8}, # Lv 3
		{"max_hp": 100, "energy": 3, "player_attack": 18, "player_defense": 12}, # Lv 4
		{"max_hp": 150, "energy": 3, "player_attack": 25, "player_defense": 18}, # Lv 5
		{"max_hp": 220, "energy": 4, "player_attack": 35, "player_defense": 25},# Lv 6
		{"max_hp": 300, "energy": 4, "player_attack": 50, "player_defense": 35},# Lv 7
		{"max_hp": 450, "energy": 4, "player_attack": 80, "player_defense": 60} # Lv 8: Unstoppable Force
	],
	"scholar": [
		{"max_hp": 10, "energy": 4, "player_attack": 1, "player_defense": 0},  # Lv 1: Very Fragile
		{"max_hp": 14, "energy": 5, "player_attack": 2, "player_defense": 0},  # Lv 2
		{"max_hp": 20, "energy": 6, "player_attack": 3, "player_defense": 1},  # Lv 3
		{"max_hp": 28, "energy": 8, "player_attack": 5, "player_defense": 1},  # Lv 4: Energy Surge
		{"max_hp": 38, "energy": 10, "player_attack": 7, "player_defense": 2}, # Lv 5
		{"max_hp": 50, "energy": 12, "player_attack": 10, "player_defense": 2},# Lv 6
		{"max_hp": 65, "energy": 15, "player_attack": 15, "player_defense": 3},# Lv 7
		{"max_hp": 85, "energy": 20, "player_attack": 25, "player_defense": 5} # Lv 8: Infinite Casting
	],
	"alchemist": [
		{"max_hp": 18, "energy": 3, "player_attack": 3, "player_defense": 1}, # Lv 1: Balanced
		{"max_hp": 28, "energy": 3, "player_attack": 5, "player_defense": 2}, # Lv 2
		{"max_hp": 42, "energy": 4, "player_attack": 8, "player_defense": 3}, # Lv 3
		{"max_hp": 60, "energy": 5, "player_attack": 12, "player_defense": 5}, # Lv 4
		{"max_hp": 85, "energy": 6, "player_attack": 18, "player_defense": 8}, # Lv 5
		{"max_hp": 115, "energy": 7, "player_attack": 25, "player_defense": 12},# Lv 6
		{"max_hp": 150, "energy": 8, "player_attack": 35, "player_defense": 18},# Lv 7
		{"max_hp": 200, "energy": 10, "player_attack": 50, "player_defense": 25} # Lv 8: Master of All
	]
}

# Identity Gauge constants
const IDENTITY_THRESHOLD_UNLOCK_NAMES = 25.0
const IDENTITY_THRESHOLD_UNCRYPT_STATS = 50.0
const IDENTITY_THRESHOLD_ASTRAL_BRIDGE = 100.0

## Helper to fetch stats for a specific level (1-indexed)
static func get_stats(class_id: String, level: int = 1) -> Dictionary:
	var idx = clamp(level - 1, 0, 7)
	if CLASS_STATS.has(class_id.to_lower()):
		return CLASS_STATS[class_id.to_lower()][idx]
	return {}

# Player Expereince 

# Progression: Level 1 starts at 0 XP. 
# Index represents Level - 1. 
# Value is total XP required to reach the NEXT level.
const XP_THRESHOLDS = [10, 50, 200, 500, 1200, 3000, 7500]

static func get_max_xp_for_level(level: int) -> int:
	if level > 0 and level <= XP_THRESHOLDS.size():
		return XP_THRESHOLDS[level - 1]
	return 99999 # Max level fallback

# LEGACY: Events - remove
const EVENTS = {
	"whispering_well": {
		"title": "The Whispering Well",
		"icon": "🕳️",
		"text": "A faint whisper promises power in exchange for a drop of life essence.",
		"choices": [
			{"text": "Offer Blood (-15 HP, +40 Gold)", "effect": "blood"},
			{"text": "Walk Away", "effect": "leave"}
		]
	},
	"traveling_merchant": {
		"title": "A Traveling Merchant",
		"icon": "🐫",
		"text": "A shady figure offers you a 'miracle tonic' for a few coins.",
		"choices": [
			{"text": "Buy Tonic (-30 Gold, +25 HP)", "effect": "buy_tonic"},
			{"text": "Refuse", "effect": "leave"}
		]
	},
	"abandoned_shrine": {
		"title": "Abandoned Shrine",
		"icon": "⛩️",
		"text": "An old shrine to a forgotten memory god. It feels heavy with static electricity.",
		"choices": [
			{"text": "Pray (Become 'Charged')", "effect": "charge"},
			{"text": "Scavenge (+15 Gold)", "effect": "scavenge"}
		]
	}
}

# LEGACY: Dialog Trees - remove
const DIALOG_TREES = {
	# --- TOWN BIOME ---
	"t1_gate_guard": {
		"start": {
			"text": "Captain Vane blocks the way out of town. 'Nobody leaves without a permit from Mayor Sterling.'",
			"options": [
				{"text": "I don't have a permit.", "next_node": "rejected"},
				{"text": "[Town Seal] Present the Mayor's Seal.", "condition": {"type": "has_item", "id": "town_seal"}, "next_node": "passed"}
			]
		},
		"rejected": {
			"text": "Then you stay in the town square. It's safer for everyone.",
			"options": [{"text": "Back to town", "action": "victory"}]
		},
		"passed": {
			"text": "The seal is authentic. Open the gates! Be careful, traveler—the forest has grown teeth lately.",
			"options": [{"text": "Enter the Forest", "action": "victory", "trigger_biome_unlock": "forest"}]
		}
	},
	"t2_tavern": {
		"start": {
			"text": "Martha the Innkeeper is wiping down the bar. 'Quiet night, traveler. Silas over there is looking for a mark.'",
			"options": [
				{"text": "Ask about Silas", "next_node": "silas_info"},
				{"text": "Buy a drink (5 Gold)", "condition": {"type": "has_gold", "amount": 5}, "action": "victory", "bonus_loot": "ale"}
			]
		},
		"silas_info": {
			"text": "He's a thief, but a useful one. He once stole a key from the Void Gate... though he'll tell you he found it.",
			"options": [{"text": "Interesting...", "action": "victory"}]
		}
	},
	"t15_mayor": {
		"start": {
			"text": "Mayor Sterling looks weary. 'The shadows in the forest are creeping closer. I need a hero.'",
			"options": [
				{"text": "I can help.", "next_node": "quest_accept"},
				{"text": "I'm just passing through.", "next_node": "dismissed"}
			]
		},
		"quest_accept": {
			"text": "Then take this Seal. It will let you past Captain Vane. Find the Mystic Elowen; she knows why the trees are screaming.",
			"options": [{"text": "Take the Town Seal", "action": "victory", "bonus_loot": "town_seal"}]
		},
		"dismissed": {
			"text": "Then go to the tavern and enjoy your ale while the world burns.",
			"options": [{"text": "Leave", "action": "victory"}]
		}
	},
	"t19_beggar": {
		"start": {
			"text": "Old Wat tugs at your cloak. 'I know you. We met... at the end. Or will we?'",
			"options": [
				{"text": "Give him a coin", "condition": {"type": "has_gold", "amount": 1}, "next_node": "prophecy"},
				{"text": "Walk away", "action": "victory"}
			]
		},
		"prophecy": {
			"text": "In the Void, look for the mirror that doesn't smile back. That's the real you.",
			"options": [{"text": "Take his strange coin", "action": "victory", "bonus_loot": "strange_coin"}]
		}
	},

	# --- FOREST BIOME ---
	"f1_encounter": {
		"start": {
			"text": "A skeletal sentry blocks the path. Its hollow eyes fix on your pack.",
			"options": [
				{"text": "Prepare to fight!", "action": "battle"},
				{"text": "[Town Seal] Show the artifact.", "condition": {"type": "has_item", "id": "town_seal"}, "next_node": "key_path"}
			]
		},
		"key_path": {
			"text": "The skeleton rattles as it bows low. 'The Mayor's mark... a soul bound to the town. Pass, Seeker.'",
			"options": [{"text": "Move past peacefully", "action": "victory"}]
		}
	},
	"f3_merchant": {
		"start": {
			"text": "Elowen the Mystic gazes at the stars. 'You carry the scent of the Mayor. He seeks a peace that no longer exists.'",
			"options": [
				{"text": "How do I reach the Ice Caves?", "next_node": "ice_path"},
				{"text": "Tell me of the Core.", "next_node": "core_info"}
			]
		},
		"ice_path": {
			"text": "The Ice Giant Brundle guards the rift. Take this Moon Essence; it will keep your heart from freezing in his presence.",
			"options": [{"text": "Take Moon Essence", "action": "victory", "bonus_loot": "moon_essence"}]
		},
		"core_info": {
			"text": "Vulcan waits at the world's heart. He seeks the Titan Hammer, lost in the crushing Abyss.",
			"options": [{"text": "Thank her", "action": "victory"}]
		}
	},
	"f16_rabbit": {
		"start": {
			"text": "A strange rabbit wiggles its nose. It seems to want you to follow it.",
			"options": [
				{"text": "Follow the rabbit", "next_node": "hidden_cache"},
				{"text": "Shoo it away", "action": "victory"}
			]
		},
		"hidden_cache": {
			"text": "It leads you to a hollow stump containing a Four-Leaf Clover.",
			"options": [{"text": "Take Clover", "action": "victory", "bonus_loot": "clover"}]
		}
	},

	# --- ICE CAVES BIOME ---
	"i1_bridge": {
		"start": {
			"text": "The Ice Golem stands frozen on the bridge. You feel the chill in your soul.",
			"options": [
				{"text": "[Moon Essence] Use the Mystic's gift.", "condition": {"type": "has_item", "id": "moon_essence"}, "next_node": "thaw_path"},
				{"text": "Attack with fire!", "action": "battle"}
			]
		},
		"thaw_path": {
			"text": "The Essence glows with a warm, silvery light. The Golem steps aside, mistaking you for a creature of the moon.",
			"options": [{"text": "Cross the bridge", "action": "victory"}]
		}
	},
	"i11_giant": {
		"start": {
			"text": "Brundle the Ice Giant towers over you. 'Tiny thing. Why you not frozen?'",
			"options": [
				{"text": "I carry the Moon's light.", "condition": {"type": "has_item", "id": "moon_essence"}, "next_node": "giant_truce"},
				{"text": "Fight for your life!", "action": "battle"}
			]
		},
		"giant_truce": {
			"text": "Brundle scratches his head. 'Moon-friend is Brundle-friend. Go. Don't fall in cracks.'",
			"options": [{"text": "Pass safely", "action": "victory"}]
		}
	},

	# --- DESERT BIOME ---
	"d5_kings": {
		"start": {
			"text": "The Mummy King Ra-Amun rises. 'To pass, you must show the Moon Essence... or die.'",
			"options": [
				{"text": "[Moon Essence] Present the essence.", "condition": {"type": "has_item", "id": "moon_essence"}, "next_node": "king_respect"},
				{"text": "I have no master!", "action": "battle"}
			]
		},
		"king_respect": {
			"text": "Ra-Amun bows. 'The stars still shine. You may seek the Sun Stone in my sanctum.'",
			"options": [{"text": "Take Sun Stone", "action": "victory", "bonus_loot": "sun_stone"}]
		}
	},
	"d16_riddle": {
		"start": {
			"text": "The Sphinx blocks the gate. 'Answer: What has no voice, yet cries? No wings, yet flies?'",
			"options": [
				{"text": "The Wind.", "next_node": "correct"},
				{"text": "A Ghost.", "next_node": "wrong"},
				{"text": "Rain.", "next_node": "wrong"}
			]
		},
		"correct": {
			"text": "The Sphinx moves aside. 'Wise traveler. Pass.'",
			"options": [{"text": "Continue", "action": "victory"}]
		},
		"wrong": {
			"text": "The Sphinx growls. 'Incorrect. Feed the sand!'",
			"options": [{"text": "Defend!", "action": "battle"}]
		}
	},

	# --- SWAMP BIOME ---
	"s2_witch": {
		"start": {
			"text": "Mother Bile stirs a bubbling pot. 'Looking for Timmy's rabbit? It's in the pot... unless you have something better.'",
			"options": [
				{"text": "[Sun Stone] Offer the King's Stone.", "condition": {"type": "has_item", "id": "sun_stone"}, "next_node": "deal_made"},
				{"text": "Give the rabbit back, hag!", "action": "battle"}
			]
		},
		"deal_made": {
			"text": "She cackles, grabbing the stone. 'A fair trade! Take the beast. It tastes like clover anyway.'",
			"options": [{"text": "Rescue the Rabbit", "action": "victory", "bonus_loot": "mr_whiskers"}]
		}
	},

	# --- ABYSS BIOME ---
	"a17_pearl": {
		"start": {
			"text": "A Giant Clam opens, revealing a pulsing black pearl. A voice echoes: 'Trade your light for my depth.'",
			"options": [
				{"text": "[Moon Essence] Give up the essence.", "condition": {"type": "has_item", "id": "moon_essence"}, "next_node": "pearl_get"},
				{"text": "Try to pry it out", "action": "battle"}
			]
		},
		"pearl_get": {
			"text": "The light fades from your pack, replaced by the heavy weight of the Black Pearl.",
			"options": [{"text": "Take Black Pearl", "action": "victory", "bonus_loot": "black_pearl"}]
		}
	},

	# --- VOID BIOME ---
	"v10_memory": {
		"start": {
			"text": "You encounter a figure that looks exactly like you. 'I am the one who failed. Will you?'",
			"options": [
				{"text": "I will succeed.", "next_node": "confidence"},
				{"text": "I am afraid.", "next_node": "fear"}
			]
		},
		"confidence": {
			"text": "The reflection fades. 'Then take my memory. Don't let it be for nothing.'",
			"options": [{"text": "Gain Memory Fragment", "action": "victory", "bonus_loot": "memory_fragment"}]
		},
		"fear": {
			"text": "The reflection lunges! 'Then let me take your place!'",
			"options": [{"text": "Fight Yourself!", "action": "battle"}]
		}
	},

	# --- THE CORE ---
	"c17_furnace": {
		"start": {
			"text": "Vulcan the Smith looks at your hands. 'Empty. Where is the Titan Hammer?'",
			"options": [
				{"text": "[Titan Hammer] Show the hammer.", "condition": {"type": "has_item", "id": "titan_hammer"}, "next_node": "final_forge"},
				{"text": "I haven't found it yet.", "next_node": "hint"}
			]
		},
		"final_forge": {
			"text": "He roars with laughter. 'Finally! Give it here. We shall forge the end of this nightmare!'",
			"options": [{"text": "Prepare for the Final Battle", "action": "victory", "trigger_event": "final_boss"}]
		},
		"hint": {
			"text": "Search the deepest trench of the Abyss. It won't come easy.",
			"options": [{"text": "Understood", "action": "victory"}]
		}
	}
}
