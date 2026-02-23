extends Node
class_name CardDatabase

# res://core/CardDatabase.gd
# The authoritative source for all card data, stats, and visual assets.

const DATA = {
	"sword": {
		"name": "Blade of Memory",
		"description": "A sharp fragment of a forgotten duel. Deals 15 damage.",
		"image": "res://assets/card/sword.png",
		"icon": "res://assets/card/icon/sword.png",
		"stats": { "damage": 15, "heal": 0, "trap": 0, "peek": 0 }
	},
	"shield": {
		"name": "Ego Barrier",
		"description": "A sturdy resolve. Prevents incoming damage.",
		"image": "res://assets/card/shield.png",
		"icon": "res://assets/card/icon/shield.png",
		"stats": { "damage": 0, "heal": 0, "trap": 0, "block": 10 }
	},
	"heart": {
		"name": "Vital Spark",
		"description": "A warm glow of existence. Heals 20 HP.",
		"image": "res://assets/card/heart.png",
		"icon": "res://assets/card/icon/heart.png",
		"stats": { "damage": 0, "heal": 20, "trap": 0, "peek": 0 }
	},
	"frost": {
		"name": "Freeze Frame",
		"description": "Chilled logic. Freezes cards in place.",
		"image": "res://assets/card/frost.png",
		"icon": "res://assets/card/icon/frost.png",
		"stats": { "damage": 0, "heal": 0, "trap": 0, "freeze": 1 }
	},
	"scroll": {
		"name": "Ancient Text",
		"description": "Looking at the inscription reveals hidden truths.",
		"image": "res://assets/card/scroll.png",
		"icon": "res://assets/card/icon/scroll.png",
		"stats": { "damage": 0, "heal": 0, "trap": 0, "peek": 3 }
	},
	"trap": {
		"name": "Dread Mimic",
		"description": "A parasitic memory. Deals 15 damage to YOU.",
		"image": "res://assets/card/trap.png",
		"icon": "res://assets/card/icon/trap.png",
		"stats": { "damage": 0, "heal": 0, "trap": 15, "peek": 0 }
	},
	"axe": {
		"name": "Heavy Cleaver",
		"description": "Brutal and direct. Deals 25 damage.",
		"image": "res://assets/card/axe.png",
		"icon": "res://assets/card/icon/axe.png",
		"stats": { "damage": 25, "heal": 0, "trap": 0, "peek": 0 }
	},
	"potion": {
		"name": "Mist Tonic",
		"description": "A swirling brew. Heals 10 HP and grants a peek.",
		"image": "res://assets/card/potion.png",
		"icon": "res://assets/card/icon/potion.png",
		"stats": { "damage": 0, "heal": 10, "trap": 0, "peek": 1 }
	},
	"bomb": {
		"name": "Chain Blast",
		"description": "Explosive recall. Damages enemies and reveals neighbors.",
		"image": "res://assets/card/bomb.png",
		"icon": "res://assets/card/icon/bomb.png",
		"stats": { "damage": 20, "heal": 0, "trap": 0, "peek": 0 }
	},
	"lightning": {
		"name": "Storm Surge",
		"description": "A flash of insight. Deals 20 damage to all.",
		"image": "res://assets/card/lightning.png",
		"icon": "res://assets/card/icon/lightning.png",
		"stats": { "damage": 20, "heal": 0, "trap": 0, "peek": 0 }
	},
	"bandage": {
		"name": "Quick Fix",
		"description": "A makeshift mend. Heals 12 HP.",
		"image": "res://assets/card/bandage.png",
		"icon": "res://assets/card/icon/bandage.png",
		"stats": { "damage": 0, "heal": 12, "trap": 0, "peek": 0 }
	},
	"dagger": {
		"name": "Hidden Spike",
		"description": "Quick and lethal. Deals 10 damage with precision.",
		"image": "res://assets/card/dagger.png",
		"icon": "res://assets/card/icon/dagger.png",
		"stats": { "damage": 10, "heal": 0, "trap": 0, "peek": 0 }
	},
	"fist": {
		"name": "Brawler's Fist",
		"description": "A basic, direct strike. Deals 8 damage.",
		"image": "res://assets/card/fist.png",
		"icon": "res://assets/card/icon/fist.png",
		"stats": { "damage": 8, "heal": 0, "trap": 0, "peek": 0 }
	},
	"kick": {
		"name": "Swift Kick",
		"description": "A forceful blow that deals 12 damage.",
		"image": "res://assets/card/kick.png",
		"icon": "res://assets/card/icon/kick.png",
		"stats": { "damage": 12, "heal": 0, "trap": 0, "peek": 0 }
	},
	"block": {
		"name": "Braced Stance",
		"description": "A standard defensive posture. Blocks 8 damage.",
		"image": "res://assets/card/block.png",
		"icon": "res://assets/card/icon/block.png",
		"stats": { "damage": 0, "heal": 0, "trap": 0, "block": 8 }
	}
}

# 'static' to allow calling from any script without an instance
static func get_card(id: String) -> Dictionary:
	return DATA.get(id, DATA["sword"])

static func get_all_ids() -> Array:
	return DATA.keys()