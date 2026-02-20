class_name GameData
extends Node

# res://data/GameData.gd
# Static repository for game content and dialog trees.

static var ROOM_POOL = {
	0: [], 1: [], 2: [], 3: [], 4: [], 5: [], 6: []
}

# Static initialization method to ensure data is ready for the generator
static func initialize_pools():
	if ROOM_POOL[0].is_empty():
		_generate_room_definitions()

static func _generate_room_definitions():
	var biomes = ["Town", "Forest", "Ice Caves", "Desert", "Swamp", "Abyss", "Void", "The Core"]
	var types = ["battle", "battle", "lore", "lore", "event", "trap", "shop", "rest"]
	
	for diff in range(7):
		var biome = biomes[diff]
		for i in range(30):
			var r_type = types[i % types.size()]
			var room_name = "%s %s %d" % [biome, r_type.capitalize(), i]
			
			if i == 0: room_name = "Entrance to the %s" % biome
			if i == 29: room_name = "The %s Threshold" % biome
			
			# Appending to a static var array works correctly
			ROOM_POOL[diff].append({
				"name": room_name,
				"type": r_type,
				"difficulty": diff,
				"enemy": _get_enemy_for_diff(diff),
				"loot": ["gold", "potion"] if r_type == "battle" else ["gold"]
			})

static func _get_enemy_for_diff(diff: int) -> String:
	# TODO: Update to allow room to dictate enemy, NPC, dialog etc  
	var enemies = ["pickpocket", "skeletal_sentry", "ice_golem", "giant_scorpion", "mud_walker", "deep_lurker", "void_stalker", "lava_slug"]
	return enemies[clampi(diff, 0, enemies.size() - 1)]

const ROOMS = {
	"town": {
		"t1": {"name": "Village Gate", "dialog": "The heavy oak gates stand open, welcoming weary travelers.", "npc_id": "gate_guard", "event_id": "whispering_well", "loot": ["map"]},
		"t2": {"name": "The Rusty Tankard", "dialog_tree": "t2_tavern", "npc_id": "innkeeper", "loot": ["ale"]},
		"t3": {"name": "Blacksmith's Forge", "dialog_tree": "t3_forge", "npc_id": "blacksmith", "loot": ["whetstone"]},
		"t4": {"name": "Apothecary Shop", "dialog": "The air smells of dried herbs and bubbling tonics.", "npc_id": "alchemist", "loot": ["potion"]},
		"t5": {"name": "Town Square", "dialog": "A bustling hub of activity. A stone fountain sits at the center.", "npc_id": "town_crier", "loot": ["coin"]},
		"t6": {"name": "General Store", "dialog_tree": "t6_store", "npc_id": "merchant", "loot": ["backpack"]},
		"t7": {"name": "Dimly Lit Alley", "dialog": "It's quieter here. Someone is watching from the shadows.", "enemy": "pickpocket", "loot": ["gold"]},
		"t8": {"name": "Old Library", "dialog": "Dust motes dance in the light filtering through stained glass.", "npc_id": "librarian", "loot": ["scroll"]},
		"t9": {"name": "The Town Well", "dialog": "The water is cool and clear. Pennies glitter at the bottom.", "loot": ["luck_charm"]},
		"t10": {"name": "Guard Barracks", "dialog": "Soldiers practice their drills in the courtyard.", "npc_id": "captain", "enemy": "training_dummy", "loot": ["shield"]},
		"t11": {"name": "Village Stables", "dialog": "The smell of hay and horses is comforting.", "npc_id": "stablehand", "loot": ["apple"]},
		"t12": {"name": "Small Chapel", "dialog": "A place of quiet contemplation and healing.", "npc_id": "priest", "loot": ["holy_water"]},
		"t13": {"name": "Baker's Hearth", "dialog": "The scent of fresh bread is nearly overwhelming.", "npc_id": "baker", "loot": ["bread"]},
		"t14": {"name": "Graveyard Path", "dialog": "The iron fence creaks. It's surprisingly well-kept.", "npc_id": "gravedigger", "loot": ["flower"]},
		"t15": {"name": "Mayor's Manor", "dialog_tree": "t15_mayor", "npc_id": "mayor", "loot": ["letter"]},
		"t16": {"name": "Hidden Cellar", "dialog": "You find a stash hidden beneath the floorboards of an old house.", "enemy": "giant_rat", "loot": ["rusty_key"]},
		"t17": {"name": "Training Grounds", "dialog": "Local militia train here to protect the village.", "npc_id": "instructor", "loot": ["wooden_sword"]},
		"t18": {"name": "Clock Tower", "dialog": "The gears turn with a rhythmic, grounding thrum.", "loot": ["pocket_watch"]},
		"t19": {"name": "Beggar's Corner", "dialog_tree": "t19_beggar", "npc_id": "old_man", "loot": ["riddle"]},
		"t20": {"name": "The Elder's Hall", "dialog": "The leaders of the town gather here to discuss the future.", "npc_id": "village_elder", "loot": ["medal"]}
	},
	"forest": {
		"f1": {"name": "Overgrown Path", "dialog_tree": "f1_encounter", "enemy": "skeletal_sentry", "loot": ["bandage"]},
		"f2": {"name": "Old Shrine", "dialog_tree": "f2_shrine", "enemy": "cultist", "loot": ["scroll"]},
		"f3": {"name": "The Wanderer", "dialog_tree": "f3_merchant", "npc_id": "merchant", "loot": ["gold"]},
		"f4": {"name": "Buzzing Hollow", "dialog": "The trees here are hollowed out by giant insects.", "enemy": "giant_bee", "loot": ["heart"]},
		"f5": {"name": "Shadow Grove", "dialog_tree": "f5_shadows", "enemy": "shadow_wraith", "loot": ["frost"]},
		"f6": {"name": "Elder Oak", "dialog": "A tree so massive its canopy blots out the sun.", "enemy": "dryad_corruptor", "loot": ["wood_charm"]},
		"f7": {"name": "Thistle Thicket", "dialog": "Thorns pull at your cloak like desperate fingers.", "enemy": "briar_beast", "loot": ["herb"]},
		"f8": {"name": "Moonlit Glade", "dialog": "A peaceful clearing, though the silence is unsettling.", "loot": ["elixir"]},
		"f9": {"name": "Hunter's Blind", "dialog": "Discarded bows and old leather rot in the humidity.", "enemy": "feral_hound", "loot": ["arrow"]},
		"f10": {"name": "Mushroom Circle", "dialog": "Spores drift through the air, causing mild hallucinations.", "enemy": "spore_servant", "loot": ["mushroom"]},
		"f11": {"name": "Creek Bed", "dialog": "The water is black and moves against the current.", "enemy": "river_lurker", "loot": ["pearl"]},
		"f12": {"name": "Spider's Web", "dialog": "Sticky silk coats every surface.", "enemy": "brood_mother", "loot": ["silk"]},
		"f13": {"name": "Logging Camp", "dialog": "Ruined wagons suggest a hasty departure.", "enemy": "forest_troll", "loot": ["axe"]},
		"f14": {"name": "Ruined Aviary", "dialog": "Feathers and broken glass litter the mossy floor.", "enemy": "harpy", "loot": ["feather"]},
		"f15": {"name": "The Great Root", "dialog": "A massive root forms a natural bridge over a ravine.", "enemy": "root_horror", "loot": ["sap"]},
		"f16": {"name": "Hidden Burrow", "dialog_tree": "f16_rabbit", "npc_id": "strange_rabbit", "loot": ["clover"]},
		"f17": {"name": "Stag's Rest", "dialog": "Bones of great beasts are piled neatly in the center.", "enemy": "bone_shaman", "loot": ["antler"]},
		"f18": {"name": "Watchtower", "dialog": "The stairs are precarious but the view is strategic.", "enemy": "bandit_archer", "loot": ["spyglass"]},
		"f19": {"name": "Willow Weep", "dialog": "The tree seems to be sobbing in the wind.", "enemy": "willow_wisp", "loot": ["tear"]},
		"f20": {"name": "Forest Heart", "dialog_tree": "f20_boss", "enemy": "forest_guardian", "loot": ["emerald_seed"]}
	},
	"ice_caves": {
		"i1": {"name": "Frost Bridge", "dialog_tree": "i1_bridge", "enemy": "ice_golem", "loot": ["frost"]},
		"i2": {"name": "Crystal Chasm", "dialog": "The walls hum with a resonant, freezing energy.", "enemy": "frost_wisp", "loot": ["lightning"]},
		"i3": {"name": "Frozen Tomb", "dialog_tree": "i3_tomb", "enemy": "tomb_wight", "loot": ["skull"]},
		"i4": {"name": "Echo Chamber", "dialog": "Your footsteps sound like a battalion following you.", "enemy": "mimic", "loot": ["trap"]},
		"i5": {"name": "Blizzard Peak", "dialog": "Visibility is near zero; the wind howls like a dying beast.", "enemy": "yeti", "loot": ["axe"]},
		"i6": {"name": "Icicle Gallery", "dialog": "Sharp spikes hang precariously from the ceiling.", "enemy": "ice_bat", "loot": ["shard"]},
		"i7": {"name": "Glacial Rift", "dialog": "The ice here is ancient and blue.", "enemy": "snow_stalker", "loot": ["claw"]},
		"i8": {"name": "Aurora Hall", "dialog": "Strange lights dance on the frozen ceiling.", "loot": ["stardust"]},
		"i9": {"name": "Sub-Zero Spring", "dialog": "The water is liquid, but burns like fire.", "enemy": "water_elemental", "loot": ["vial"]},
		"i10": {"name": "Frozen Library", "dialog": "Pages of books are trapped in sheets of ice.", "enemy": "ghost_scholar", "loot": ["tome"]},
		"i11": {"name": "Sleeping Giant", "dialog_tree": "i11_giant", "npc_id": "ice_giant", "loot": ["club"]},
		"i12": {"name": "Permafrost Mine", "dialog": "Pickaxes are still embedded in the walls.", "enemy": "kobold_miner", "loot": ["ore"]},
		"i13": {"name": "Snowdrift", "dialog": "You sink waist-deep in the powder.", "enemy": "snow_leopard", "loot": ["pelt"]},
		"i14": {"name": "The Cold Forge", "dialog": "An anvil that freezes everything it touches.", "enemy": "ice_smith", "loot": ["hammer"]},
		"i15": {"name": "Whiteout Tunnel", "dialog": "The wind is a physical wall pushing you back.", "enemy": "blizzard_wraith", "loot": ["essence"]},
		"i16": {"name": "Crystal Garden", "dialog": "Plants made of glass grow in the dark.", "enemy": "shard_shifter", "loot": ["crystal"]},
		"i17": {"name": "Mammoth Graveyard", "dialog": "Tusks larger than trees rise from the snow.", "enemy": "necro_mammoth", "loot": ["ivory"]},
		"i18": {"name": "Hidden Grotto", "dialog_tree": "i18_hermit", "npc_id": "frost_hermit", "loot": ["soup"]},
		"i19": {"name": "Ice Throne", "dialog": "A seat carved for someone twenty feet tall.", "enemy": "ice_lich", "loot": ["crown"]},
		"i20": {"name": "The Glacier Heart", "dialog_tree": "i20_boss", "enemy": "cryo_phoenix", "loot": ["eternal_ice"]}
	},
	"desert": {
		"d1": {"name": "Sun-Bleached Dunes", "dialog": "The heat is a physical weight pushing you down.", "enemy": "giant_scorpion", "loot": ["heart"]},
		"d2": {"name": "Mirage Oasis", "dialog_tree": "d2_oasis", "enemy": "sand_spirit", "loot": ["potion"]},
		"d3": {"name": "Ruined Outpost", "dialog": "Soldiers died here long ago. Their armor is rusted to the bone.", "enemy": "skeleton_soldier", "loot": ["sword"]},
		"d4": {"name": "Obsidian Pillar", "dialog": "A black spire that seems to drink the sunlight.", "enemy": "fire_imp", "loot": ["bomb"]},
		"d5": {"name": "Valley of Kings", "dialog_tree": "d5_kings", "enemy": "mummy_king", "loot": ["bandage"]},
		"d6": {"name": "Sandstorm Eye", "dialog": "The center of the storm is eerily quiet.", "enemy": "dust_devil", "loot": ["sand_glass"]},
		"d7": {"name": "Beetle Burrow", "dialog": "Clicking sounds echo from beneath the sand.", "enemy": "scarab_swarm", "loot": ["shell"]},
		"d8": {"name": "Dried Well", "dialog": "Hope died here a long time ago.", "enemy": "ghoul", "loot": ["bucket"]},
		"d9": {"name": "Salt Flats", "dialog": "The ground is white and cracked like broken pottery.", "enemy": "salt_golem", "loot": ["salt"]},
		"d10": {"name": "Nomad Camp", "dialog_tree": "d10_camp", "npc_id": "sheik", "loot": ["cloth"]},
		"d11": {"name": "Cactus Forest", "dialog": "Prickly giants loom over the path.", "enemy": "needle_fiend", "loot": ["fruit"]},
		"d12": {"name": "Glass Canyon", "dialog": "Heat has fused the sand into jagged glass.", "enemy": "shard_beast", "loot": ["glass"]},
		"d13": {"name": "Abandoned Bazaar", "dialog": "Tattered silks flap in the dry wind.", "enemy": "thief_shade", "loot": ["coin"]},
		"d14": {"name": "Sun Temple", "dialog": "Gold mirrors reflect blinding beams of light.", "enemy": "solar_priest", "loot": ["gold_bar"]},
		"d15": {"name": "Quick Sand", "dialog": "Every step requires careful planning.", "enemy": "sand_kraken", "loot": ["tentacle"]},
		"d16": {"name": "Sphinx Gate", "dialog_tree": "d16_riddle", "enemy": "guardian_sphinx", "loot": ["feather"]},
		"d17": {"name": "The Red Mesa", "dialog": "The rock is the color of dried blood.", "enemy": "canyon_harpy", "loot": ["ruby"]},
		"d18": {"name": "Dusty Vault", "dialog": "A heavy door keeps the secrets of the sand.", "enemy": "mimic_chest", "loot": ["relic"]},
		"d19": {"name": "Searing Overlook", "dialog": "From here, the desert looks like an endless ocean.", "enemy": "vulture_lord", "loot": ["eye"]},
		"d20": {"name": "Pharaoh's Sanctum", "dialog_tree": "d20_boss", "enemy": "god_king_ra", "loot": ["sun_stone"]}
	},
	"swamp": {
		"s1": {"name": "Peat Bog", "dialog": "The ground bubbles with methane and decay.", "enemy": "mud_walker", "loot": ["peat"]},
		"s2": {"name": "Sunken Hut", "dialog_tree": "s2_witch", "npc_id": "swamp_hag", "loot": ["brew"]},
		"s3": {"name": "Willow Weep", "dialog": "Moss hangs like curtains from the rotting trees.", "enemy": "bog_horror", "loot": ["moss"]},
		"s4": {"name": "Firefly Marsh", "dialog": "Tiny lights offer a deceptive sense of safety.", "enemy": "willow_wisp", "loot": ["light_dust"]},
		"s5": {"name": "Crocodile Creek", "dialog": "Logs in the water suddenly sprout eyes.", "enemy": "giant_croc", "loot": ["leather"]},
		"s6": {"name": "Mist Veil", "dialog": "You can't see your hand in front of your face.", "enemy": "mist_stalker", "loot": ["vapor"]},
		"s7": {"name": "Leech Pool", "dialog": "The water is thick and dark.", "enemy": "leech_swarm", "loot": ["blood"]},
		"s8": {"name": "Rusting Ferry", "dialog": "A boat sits half-submerged in the muck.", "enemy": "drowned_sailor", "loot": ["nail"]},
		"s9": {"name": "Tangled Mangroves", "dialog": "The roots are a natural cage.", "enemy": "vine_strangler", "loot": ["vine"]},
		"s10": {"name": "Bubbling Mire", "dialog": "The smell of sulfur is overwhelming.", "enemy": "ooze_cube", "loot": ["slime"]},
		"s11": {"name": "Deadwood Bridge", "dialog": "The planks groan with every movement.", "enemy": "bridge_troll", "loot": ["wood"]},
		"s12": {"name": "Mosquito Hive", "dialog": "A constant drone fills your ears.", "enemy": "blood_flyer", "loot": ["proboscis"]},
		"s13": {"name": "Shrunken Head Totem", "dialog": "The trophies seem to watch you.", "enemy": "witch_doctor", "loot": ["mask"]},
		"s14": {"name": "Sunken Altar", "dialog": "An ancient god is being reclaimed by the mud.", "enemy": "naga_siren", "loot": ["scale"]},
		"s15": {"name": "Blackwater Dock", "dialog": "Old fishing nets are filled with bones.", "enemy": "crab_monstrosity", "loot": ["shell"]},
		"s16": {"name": "Foggy Meadow", "dialog": "The grass is razor sharp.", "enemy": "swamp_cat", "loot": ["claw"]},
		"s17": {"name": "Blighted Orchard", "dialog": "Fruit here is black and dripping with bile.", "enemy": "rot_spirit", "loot": ["spore"]},
		"s18": {"name": "Hermit's Stump", "dialog_tree": "s18_hermit", "npc_id": "old_man_bog", "loot": ["pipe"]},
		"s19": {"name": "Grave of Giants", "dialog": "Ribcages rise from the swamp like arches.", "enemy": "undead_giant", "loot": ["bone"]},
		"s20": {"name": "The Heart of Decay", "dialog_tree": "s20_boss", "enemy": "the_hydra", "loot": ["hydra_scale"]}
	},
	"abyss": {
		"a1": {"name": "Crushing Trench", "dialog": "The pressure here makes your bones ache.", "enemy": "deep_lurker", "loot": ["iron"]},
		"a2": {"name": "Bioluminescent Reef", "dialog": "Strange corals glow with a sickly neon light.", "enemy": "glow_eel", "loot": ["neon_ink"]},
		"a3": {"name": "Sunken Galleon", "dialog": "Gold glitters among the rotted wood.", "enemy": "drowned_captain", "loot": ["doubloon"]},
		"a4": {"name": "Pressure Chamber", "dialog": "A pocket of air in the deep sea.", "npc_id": "diver", "loot": ["oxygen"]},
		"a5": {"name": "Whale Fall", "dialog": "A massive skeleton sustains a small ecosystem.", "enemy": "bone_picker", "loot": ["oil"]},
		"a6": {"name": "Thermal Vent", "dialog": "Scalding water shoots from the sea floor.", "enemy": "heat_crab", "loot": ["sulfur"]},
		"a7": {"name": "Silent Cathedral", "dialog": "A massive underwater cave where sound dies.", "enemy": "void_ray", "loot": ["echo"]},
		"a8": {"name": "The Maw", "dialog": "A cave entrance that looks like a row of teeth.", "enemy": "angler_fiend", "loot": ["lamp"]},
		"a9": {"name": "Jellyfish Forest", "dialog": "Stinging tentacles hang like vines.", "enemy": "shock_jelly", "loot": ["gel"]},
		"a10": {"name": "Coral Throne", "dialog": "The ruler of the deep sat here once.", "enemy": "merrow_king", "loot": ["trident"]},
		"a11": {"name": "Dark Current", "dialog": "A fast moving stream of freezing water.", "enemy": "current_wraith", "loot": ["water_essence"]},
		"a12": {"name": "Lost City Gates", "dialog": "Architecture that defies human logic.", "enemy": "stone_guardian", "loot": ["glyph"]},
		"a13": {"name": "Octopus Den", "dialog": "Ink clouds the water at the slightest movement.", "enemy": "mimic_octopus", "loot": ["ink"]},
		"a14": {"name": "The Abyss Wall", "dialog": "A cliff that drops into infinite darkness.", "enemy": "climbing_horror", "loot": ["hook"]},
		"a15": {"name": "Sunken Library", "dialog": "The books are made of etched stone.", "enemy": "archive_spirit", "loot": ["slate"]},
		"a16": {"name": "Obsidian Ridge", "dialog": "Sharp volcanic rock cuts through your boots.", "enemy": "lava_fish", "loot": ["magma_stone"]},
		"a17": {"name": "Pearl Grotto", "dialog_tree": "a17_pearl", "npc_id": "clam_god", "loot": ["giant_pearl"]},
		"a18": {"name": "Kelp Tangle", "dialog": "The seaweed seems to move on its own.", "enemy": "kelp_fiend", "loot": ["fiber"]},
		"a19": {"name": "Deep Forge", "dialog": "Forging weapons using the heat of the earth.", "enemy": "abyssal_smith", "loot": ["dark_steel"]},
		"a20": {"name": "Leviathan's Bed", "dialog_tree": "a20_boss", "enemy": "the_leviathan", "loot": ["ocean_heart"]}
	},
	"void": {
		"v1": {"name": "Void Gate", "dialog_tree": "v1_gate", "enemy": "void_stalker", "loot": ["scroll"]},
		"v2": {"name": "Mind Maze", "dialog_tree": "v2_mirror", "enemy": "brain_eater", "loot": ["lightning"]},
		"v3": {"name": "Blood Fountain", "dialog": "A metallic scent fills the air; the liquid is warm.", "enemy": "vampire_lord", "loot": ["heart"]},
		"v4": {"name": "Obsidian Forge", "dialog": "The hammers never stop, even with no one at the anvils.", "enemy": "forge_automaton", "loot": ["shield"]},
		"v5": {"name": "Final Descent", "dialog": "This is the end of the line. The air is still.", "enemy": "the_keeper", "loot": ["key"]},
		"v6": {"name": "Event Horizon", "dialog": "Light stretches and breaks in this place.", "enemy": "gravity_well", "loot": ["singularity"]},
		"v7": {"name": "Fractal Edge", "dialog": "The walls repeat infinitely into the distance.", "enemy": "echo_shade", "loot": ["mirror"]},
		"v8": {"name": "Null Space", "dialog": "There is no color here, only static.", "enemy": "glitch_horror", "loot": ["binary_code"]},
		"v9": {"name": "The Rift", "dialog": "A tear in reality leaking purple energy.", "enemy": "rift_walker", "loot": ["void_energy"]},
		"v10": {"name": "Memory Fragment", "dialog_tree": "v10_memory", "npc_id": "past_self", "loot": ["tear"]},
		"v11": {"name": "Echoing Silence", "dialog": "The lack of sound is deafening.", "enemy": "silent_one", "loot": ["muffled_bell"]},
		"v12": {"name": "Gravity Flip", "dialog": "Up is down, and you feel nauseous.", "enemy": "inverse_specter", "loot": ["magnet"]},
		"v13": {"name": "Star Nursery", "dialog": "Gases swirl to create new suns.", "enemy": "nebula_beast", "loot": ["stardust"]},
		"v14": {"name": "The Unmaking", "dialog": "Things here are slowly dissolving into nothing.", "enemy": "entropy_fiend", "loot": ["dust"]},
		"v15": {"name": "Glass Ceiling", "dialog": "You can see other worlds through the floor.", "enemy": "watcher", "loot": ["glass_eye"]},
		"v16": {"name": "Void Market", "dialog_tree": "v16_market", "npc_id": "void_trader", "loot": ["strange_coin"]},
		"v17": {"name": "Clockwork Void", "dialog": "Massive gears turn without purpose.", "enemy": "time_keeper", "loot": ["gear"]},
		"v18": {"name": "Shadow Theatre", "dialog": "Shadows act out your greatest fears.", "enemy": "fear_phantom", "loot": ["mask"]},
		"v19": {"name": "Last Outpost", "dialog": "A small shack holding back the nothingness.", "npc_id": "survivor", "loot": ["hope"]},
		"v20": {"name": "The Singularity", "dialog_tree": "v20_boss", "enemy": "void_emperor", "loot": ["universe_core"]}
	},
	"the_core": {
		"c1": {"name": "Magma River", "dialog": "A flow of molten rock cuts through the chamber.", "enemy": "lava_slug", "loot": ["fire_shard"]},
		"c2": {"name": "Steam Vent", "dialog": "High-pressure steam screams through the cracks.", "enemy": "steam_mephit", "loot": ["vapor"]},
		"c3": {"name": "Iron Foundry", "dialog": "The sound of clashing metal is constant.", "enemy": "iron_golem", "loot": ["iron_bar"]},
		"c4": {"name": "Basalt Bridge", "dialog": "A narrow path over a lake of fire.", "enemy": "fire_bat", "loot": ["coal"]},
		"c5": {"name": "Sulfur Pit", "dialog": "Yellow fumes choke your breath.", "enemy": "sulfur_spirit", "loot": ["sulfur"]},
		"c6": {"name": "The Great Smelter", "dialog": "Heat so intense it melts your armor.", "enemy": "smelter_demon", "loot": ["molten_core"]},
		"c7": {"name": "Diamond Crag", "dialog": "Pressure has turned the coal into hard gems.", "enemy": "rock_spider", "loot": ["diamond"]},
		"c8": {"name": "Geothermal Well", "dialog": "Natural energy pulses from the ground.", "loot": ["battery"]},
		"c9": {"name": "Ash Plain", "dialog": "Walking here leaves deep tracks in the soot.", "enemy": "ash_wraith", "loot": ["urn"]},
		"c10": {"name": "Machinery Hall", "dialog": "Pistons move with rhythmic precision.", "enemy": "automaton_scout", "loot": ["spring"]},
		"c11": {"name": "Cinder Grove", "dialog": "Trees made of charcoal still burn with heat.", "enemy": "cinder_cat", "loot": ["charcoal"]},
		"c12": {"name": "The Boiler", "dialog": "The humidity is 100% and it's boiling.", "enemy": "pressure_fiend", "loot": ["valve"]},
		"c13": {"name": "Molten Waterfall", "dialog": "Liquid gold falls from the ceiling.", "enemy": "gold_elemental", "loot": ["gold_nugget"]},
		"c14": {"name": "Obsidian Lab", "dialog": "Dark stones used for magical experiments.", "enemy": "fire_mage", "loot": ["wand"]},
		"c15": {"name": "Ventilation Shaft", "dialog": "A cool breeze comes from somewhere above.", "enemy": "harpy_scout", "loot": ["fan"]},
		"c16": {"name": "The Great Engine", "dialog": "This machine powers the entire world.", "enemy": "engine_master", "loot": ["power_cell"]},
		"c17": {"name": "Crystal Furnace", "dialog_tree": "c17_furnace", "npc_id": "the_smith", "loot": ["fire_sword"]},
		"c18": {"name": "Red Rock Vault", "dialog": "The stones here hum with heat.", "enemy": "mimic_safe", "loot": ["relic"]},
		"c19": {"name": "Scorched Path", "dialog": "Everything here has been burned to a crisp.", "enemy": "phoenix_hatchling", "loot": ["feather"]},
		"c20": {"name": "The Heart of the World", "dialog_tree": "c20_boss", "enemy": "magma_titan", "loot": ["core_essence"]}
	}
}

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

# --- ENEMIES ---
# Centralized stats and loot for combat rewards.
const ENEMIES = {
	# --- TOWN BIOME (Tutorial / Easy) ---
	"pickpocket": {
		"name": "Pickpocket",
		"hp": 12, "attack": 3, "biome": "town",
		"icon": "res://assets/enemy/dagger.png",
		# Probability Array: [Attack, Critical, Debuff, Pass]
		"probabilities": [0.5, 0.2, 0.2, 0.1], 
		"loot": [{"id": "gold", "min": 5, "max": 15}]
	},
	"training_dummy": {
		"name": "Training Dummy",
		"hp": 50, "attack": 0, "armor": 2, "biome": "town",
		"icon": "res://assets/enemy/trap.png",
		"probabilities": [0.0, 0.0, 0.0, 1.0], 
		"loot": ["wood_splinter"]
	},
	"giant_rat": {
		"name": "Giant Rat",
		"hp": 10, "attack": 4, "biome": "town",
		"icon": "res://assets/enemy/skull.png",
		"probabilities": [1.0, 0.0, 0.0, 0.0], 
		"loot": ["tail", {"id": "gold", "min": 1, "max": 3}]
	},
	"drunk_patron": {
		"name": "Drunk Patron",
		"hp": 20, "attack": 5, "biome": "town",
		"icon": "res://assets/enemy/ale.png",
		"loot": ["ale", "coin"]
	},
	"ruffian": {
		"name": "Alley Ruffian",
		"hp": 25, "attack": 6, "biome": "town",
		"icon": "res://assets/enemy/dagger.png",
		"loot": [{"id": "gold", "min": 10, "max": 20}]
	},
	"cat_thief": {
		"name": "Cat Thief",
		"hp": 15, "attack": 8, "biome": "town",
		"icon": "res://assets/enemy/cloak.png",
		"loot": ["lockpick"]
	},
	"corrupt_clerk": {
		"name": "Corrupt Clerk",
		"hp": 18, "attack": 4, "biome": "town",
		"icon": "res://assets/enemy/scroll.png",
		"loot": ["tax_form", "gold"]
	},
	"feral_cat": {
		"name": "Feral Cat",
		"hp": 8, "attack": 7, "biome": "town",
		"icon": "res://assets/enemy/claws.png",
		"loot": ["fur"]
	},
	"loose_armor": {
		"name": "Animated Armor",
		"hp": 30, "attack": 5, "armor": 5, "biome": "town",
		"icon": "res://assets/enemy/shield.png",
		"loot": ["iron_scrap"]
	},
	"town_bully": {
		"name": "Town Bully",
		"hp": 35, "attack": 6, "biome": "town",
		"icon": "res://assets/enemy/fist.png",
		"loot": ["stolen_lunch"]
	},

	# --- FOREST BIOME ---
	"skeletal_sentry": {
		"name": "Skeletal Sentry",
		"hp": 25, "attack": 5, "biome": "forest",
		"icon": "res://assets/enemy/skull.png",
		"loot": [{"id": "gold", "min": 2, "max": 8}, "skull"]
	},
	"giant_bee": {
		"name": "Giant Bee",
		"hp": 15, "attack": 12, "biome": "forest",
		"icon": "res://assets/enemy/bee.png",
		"loot": ["honey"]
	},
	"cultist": {
		"name": "Cultist",
		"hp": 30, "attack": 7, "biome": "forest",
		"icon": "res://assets/enemy/scroll.png",
		"loot": ["scroll", {"id": "gold", "min": 5, "max": 12}]
	},
	"shadow_wraith": {
		"name": "Shadow Wraith",
		"hp": 40, "attack": 9, "biome": "forest",
		"icon": "res://assets/enemy/ghost.png",
		"loot": ["shadow_essence"]
	},
	"dryad_corruptor": {
		"name": "Corrupted Dryad",
		"hp": 45, "attack": 8, "biome": "forest",
		"icon": "res://assets/enemy/leaf.png",
		"loot": ["emerald_seed"]
	},
	"briar_beast": {
		"name": "Briar Beast",
		"hp": 55, "attack": 10, "armor": 3, "biome": "forest",
		"icon": "res://assets/enemy/thorn.png",
		"loot": ["vine"]
	},
	"feral_hound": {
		"name": "Feral Hound",
		"hp": 20, "attack": 11, "biome": "forest",
		"icon": "res://assets/enemy/fang.png",
		"loot": ["pelt"]
	},
	"spore_servant": {
		"name": "Spore Servant",
		"hp": 35, "attack": 6, "biome": "forest",
		"icon": "res://assets/enemy/mushroom.png",
		"loot": ["mushroom"]
	},
	"river_lurker": {
		"name": "River Lurker",
		"hp": 40, "attack": 9, "biome": "forest",
		"icon": "res://assets/enemy/water.png",
		"loot": ["pearl"]
	},
	"brood_mother": {
		"name": "Brood Mother",
		"hp": 100, "attack": 15, "biome": "forest",
		"icon": "res://assets/enemy/spider.png",
		"loot": ["silk", "venom"]
	},

	# --- ICE CAVES BIOME ---
	"ice_golem": {
		"name": "Ice Golem",
		"hp": 80, "attack": 12, "armor": 8, "biome": "ice_caves",
		"icon": "res://assets/enemy/frost.png",
		"loot": [{"id": "gold", "min": 15, "max": 25}, "frost"]
	},
	"yeti": {
		"name": "Yeti",
		"hp": 120, "attack": 18, "biome": "ice_caves",
		"icon": "res://assets/enemy/skull.png",
		"loot": [{"id": "gold", "min": 40, "max": 80}, "axe"]
	},
	"frost_wisp": {
		"name": "Frost Wisp",
		"hp": 30, "attack": 15, "biome": "ice_caves",
		"icon": "res://assets/enemy/lightning.png",
		"loot": ["frozen_tear"]
	},
	"tomb_wight": {
		"name": "Tomb Wight",
		"hp": 65, "attack": 14, "biome": "ice_caves",
		"icon": "res://assets/enemy/skull.png",
		"loot": ["ancient_coin"]
	},
	"mimic": {
		"name": "Frost Mimic",
		"hp": 90, "attack": 20, "armor": 4, "biome": "ice_caves",
		"icon": "res://assets/enemy/trap.png",
		"loot": ["trap", "gold"]
	},
	"ice_bat": {
		"name": "Ice Bat",
		"hp": 25, "attack": 10, "biome": "ice_caves",
		"icon": "res://assets/enemy/wing.png",
		"loot": ["shard"]
	},
	"snow_stalker": {
		"name": "Snow Stalker",
		"hp": 70, "attack": 22, "biome": "ice_caves",
		"icon": "res://assets/enemy/claw.png",
		"loot": ["white_fur"]
	},
	"water_elemental": {
		"name": "Freezing Elemental",
		"hp": 85, "attack": 16, "biome": "ice_caves",
		"icon": "res://assets/enemy/vial.png",
		"loot": ["vial"]
	},
	"ghost_scholar": {
		"name": "Ghost Scholar",
		"hp": 50, "attack": 25, "biome": "ice_caves",
		"icon": "res://assets/enemy/tome.png",
		"loot": ["tome"]
	},
	"kobold_miner": {
		"name": "Kobold Miner",
		"hp": 45, "attack": 12, "biome": "ice_caves",
		"icon": "res://assets/enemy/ore.png",
		"loot": ["ore", "gold"]
	},

	# --- DESERT BIOME ---
	"giant_scorpion": {
		"name": "Giant Scorpion",
		"hp": 110, "attack": 25, "armor": 10, "biome": "desert",
		"icon": "res://assets/enemy/heart.png",
		"loot": ["poison_gland", "heart"]
	},
	"sand_spirit": {
		"name": "Sand Spirit",
		"hp": 70, "attack": 30, "biome": "desert",
		"icon": "res://assets/enemy/potion.png",
		"loot": ["potion"]
	},
	"skeleton_soldier": {
		"name": "Desert Soldier",
		"hp": 90, "attack": 22, "biome": "desert",
		"icon": "res://assets/enemy/sword.png",
		"loot": ["rusty_sword"]
	},
	"fire_imp": {
		"name": "Fire Imp",
		"hp": 50, "attack": 35, "biome": "desert",
		"icon": "res://assets/enemy/bomb.png",
		"loot": ["bomb"]
	},
	"mummy_king": {
		"name": "Mummy King",
		"hp": 200, "attack": 30, "armor": 5, "biome": "desert",
		"icon": "res://assets/enemy/bandage.png",
		"loot": ["golden_bandage"]
	},
	"dust_devil": {
		"name": "Dust Devil",
		"hp": 60, "attack": 28, "biome": "desert",
		"icon": "res://assets/enemy/lightning.png",
		"loot": ["sand_glass"]
	},
	"scarab_swarm": {
		"name": "Scarab Swarm",
		"hp": 40, "attack": 40, "biome": "desert",
		"icon": "res://assets/enemy/trap.png",
		"loot": ["carapace"]
	},
	"ghoul": {
		"name": "Desert Ghoul",
		"hp": 85, "attack": 24, "biome": "desert",
		"icon": "res://assets/enemy/skull.png",
		"loot": ["rotten_flesh"]
	},
	"salt_golem": {
		"name": "Salt Golem",
		"hp": 150, "attack": 20, "armor": 15, "biome": "desert",
		"icon": "res://assets/enemy/ore.png",
		"loot": ["salt_crystal"]
	},
	"shard_beast": {
		"name": "Shard Beast",
		"hp": 100, "attack": 32, "biome": "desert",
		"icon": "res://assets/enemy/glass.png",
		"loot": ["glass_shard"]
	},

	# --- SWAMP BIOME ---
	"mud_walker": {
		"name": "Mud Walker",
		"hp": 140, "attack": 25, "armor": 5, "biome": "swamp",
		"icon": "res://assets/enemy/mud.png",
		"loot": ["peat"]
	},
	"bog_horror": {
		"name": "Bog Horror",
		"hp": 180, "attack": 35, "biome": "swamp",
		"icon": "res://assets/enemy/skull.png",
		"loot": ["moss"]
	},
	"willow_wisp": {
		"name": "Willow Wisp",
		"hp": 50, "attack": 45, "biome": "swamp",
		"icon": "res://assets/enemy/light.png",
		"loot": ["light_dust"]
	},
	"giant_croc": {
		"name": "Giant Crocodile",
		"hp": 220, "attack": 40, "armor": 12, "biome": "swamp",
		"icon": "res://assets/enemy/claws.png",
		"loot": ["leather"]
	},
	"mist_stalker": {
		"name": "Mist Stalker",
		"hp": 110, "attack": 38, "biome": "swamp",
		"icon": "res://assets/enemy/ghost.png",
		"loot": ["vapor"]
	},
	"leech_swarm": {
		"name": "Leech Swarm",
		"hp": 60, "attack": 50, "biome": "swamp",
		"icon": "res://assets/enemy/blood.png",
		"loot": ["blood_vial"]
	},
	"drowned_sailor": {
		"name": "Drowned Sailor",
		"hp": 130, "attack": 30, "biome": "swamp",
		"icon": "res://assets/enemy/sword.png",
		"loot": ["rusty_nail"]
	},
	"vine_strangler": {
		"name": "Vine Strangler",
		"hp": 150, "attack": 32, "biome": "swamp",
		"icon": "res://assets/enemy/leaf.png",
		"loot": ["vine"]
	},
	"ooze_cube": {
		"name": "Ooze Cube",
		"hp": 200, "attack": 20, "armor": 20, "biome": "swamp",
		"icon": "res://assets/enemy/slime.png",
		"loot": ["slime"]
	},
	"blood_flyer": {
		"name": "Blood Flyer",
		"hp": 80, "attack": 42, "biome": "swamp",
		"icon": "res://assets/enemy/wing.png",
		"loot": ["proboscis"]
	},

	# --- ABYSS BIOME ---
	"deep_lurker": {
		"name": "Deep Lurker",
		"hp": 250, "attack": 45, "armor": 15, "biome": "abyss",
		"icon": "res://assets/enemy/eye.png",
		"loot": ["heavy_iron"]
	},
	"glow_eel": {
		"name": "Glow Eel",
		"hp": 150, "attack": 55, "biome": "abyss",
		"icon": "res://assets/enemy/lightning.png",
		"loot": ["neon_ink"]
	},
	"drowned_captain": {
		"name": "Drowned Captain",
		"hp": 300, "attack": 50, "armor": 10, "biome": "abyss",
		"icon": "res://assets/enemy/sword.png",
		"loot": ["gold_doubloon"]
	},
	"bone_picker": {
		"name": "Bone Picker",
		"hp": 180, "attack": 48, "biome": "abyss",
		"icon": "res://assets/enemy/skull.png",
		"loot": ["whale_oil"]
	},
	"heat_crab": {
		"name": "Heat Crab",
		"hp": 220, "attack": 42, "armor": 25, "biome": "abyss",
		"icon": "res://assets/enemy/claws.png",
		"loot": ["sulfur"]
	},
	"void_ray": {
		"name": "Void Ray",
		"hp": 160, "attack": 60, "biome": "abyss",
		"icon": "res://assets/enemy/wing.png",
		"loot": ["echo_essence"]
	},
	"angler_fiend": {
		"name": "Angler Fiend",
		"hp": 280, "attack": 65, "biome": "abyss",
		"icon": "res://assets/enemy/light.png",
		"loot": ["biolamp"]
	},
	"shock_jelly": {
		"name": "Shock Jelly",
		"hp": 120, "attack": 75, "biome": "abyss",
		"icon": "res://assets/enemy/lightning.png",
		"loot": ["electric_gel"]
	},
	"merrow_king": {
		"name": "Merrow King",
		"hp": 400, "attack": 55, "armor": 20, "biome": "abyss",
		"icon": "res://assets/enemy/trident.png",
		"loot": ["trident_tip"]
	},
	"current_wraith": {
		"name": "Current Wraith",
		"hp": 200, "attack": 62, "biome": "abyss",
		"icon": "res://assets/enemy/water.png",
		"loot": ["ocean_tear"]
	},

	# --- VOID BIOME ---
	"void_stalker": {
		"name": "Void Stalker",
		"hp": 400, "attack": 70, "armor": 20, "biome": "void",
		"icon": "res://assets/enemy/skull.png",
		"loot": ["void_scroll"]
	},
	"brain_eater": {
		"name": "Brain Eater",
		"hp": 350, "attack": 85, "biome": "void",
		"icon": "res://assets/enemy/lightning.png",
		"loot": ["mind_essence"]
	},
	"vampire_lord": {
		"name": "Vampire Lord",
		"hp": 500, "attack": 80, "armor": 15, "biome": "void",
		"icon": "res://assets/enemy/heart.png",
		"loot": ["ancient_heart"]
	},
	"forge_automaton": {
		"name": "Forge Automaton",
		"hp": 600, "attack": 65, "armor": 40, "biome": "void",
		"icon": "res://assets/enemy/shield.png",
		"loot": ["obsidian_plate"]
	},
	"the_keeper": {
		"name": "The Keeper",
		"hp": 1000, "attack": 100, "armor": 50, "biome": "void",
		"icon": "res://assets/enemy/key.png",
		"loot": ["master_key"]
	},
	"gravity_well": {
		"name": "Gravity Well",
		"hp": 450, "attack": 95, "biome": "void",
		"icon": "res://assets/enemy/bomb.png",
		"loot": ["singularity"]
	},
	"echo_shade": {
		"name": "Echo Shade",
		"hp": 300, "attack": 110, "biome": "void",
		"icon": "res://assets/enemy/ghost.png",
		"loot": ["dark_mirror"]
	},
	"glitch_horror": {
		"name": "Glitch Horror",
		"hp": 380, "attack": 120, "biome": "void",
		"icon": "res://assets/enemy/scroll.png",
		"loot": ["corrupt_data"]
	},
	"rift_walker": {
		"name": "Rift Walker",
		"hp": 420, "attack": 90, "biome": "void",
		"icon": "res://assets/enemy/wing.png",
		"loot": ["void_shard"]
	},
	"silent_one": {
		"name": "Silent One",
		"hp": 550, "attack": 75, "armor": 30, "biome": "void",
		"icon": "res://assets/enemy/skull.png",
		"loot": ["muffled_tongue"]
	},

	# --- THE CORE BIOME ---
	"lava_slug": {
		"name": "Lava Slug",
		"hp": 600, "attack": 90, "armor": 30, "biome": "the_core",
		"icon": "res://assets/enemy/fire.png",
		"loot": ["fire_shard"]
	},
	"steam_mephit": {
		"name": "Steam Mephit",
		"hp": 400, "attack": 120, "biome": "the_core",
		"icon": "res://assets/enemy/vapor.png",
		"loot": ["cloud_essence"]
	},
	"iron_golem": {
		"name": "Core Guardian",
		"hp": 1200, "attack": 100, "armor": 80, "biome": "the_core",
		"icon": "res://assets/enemy/shield.png",
		"loot": ["pure_iron"]
	},
	"fire_bat": {
		"name": "Fire Bat",
		"hp": 350, "attack": 110, "biome": "the_core",
		"icon": "res://assets/enemy/wing.png",
		"loot": ["ember"]
	},
	"sulfur_spirit": {
		"name": "Sulfur Spirit",
		"hp": 500, "attack": 130, "biome": "the_core",
		"icon": "res://assets/enemy/vapor.png",
		"loot": ["sulfur_dust"]
	},
	"smelter_demon": {
		"name": "Smelter Demon",
		"hp": 1500, "attack": 150, "armor": 60, "biome": "the_core",
		"icon": "res://assets/enemy/fire.png",
		"loot": ["molten_core"]
	},
	"rock_spider": {
		"name": "Diamond Spider",
		"hp": 800, "attack": 115, "armor": 100, "biome": "the_core",
		"icon": "res://assets/enemy/spider.png",
		"loot": ["diamond"]
	},
	"ash_wraith": {
		"name": "Ash Wraith",
		"hp": 650, "attack": 140, "biome": "the_core",
		"icon": "res://assets/enemy/ghost.png",
		"loot": ["ash_pile"]
	},
	"automaton_scout": {
		"name": "Core Scout",
		"hp": 550, "attack": 125, "armor": 45, "biome": "the_core",
		"icon": "res://assets/enemy/eye.png",
		"loot": ["power_cell"]
	},
	"cinder_cat": {
		"name": "Cinder Cat",
		"hp": 700, "attack": 160, "biome": "the_core",
		"icon": "res://assets/enemy/claws.png",
		"loot": ["burning_pelt"]
	}
}

const NPCS = {
	# --- TOWN BIOME ---
	"blacksmith": {
		"name": "Grimbald", "biome": "town",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 100, "strength": 15},
		"dialog": {
			"initial": "Need your blade sharpened, traveler? My master Vulcan taught me everything, though he's gone deep into the Core now.",
			"after_save": "You saved my shop. For you, the first one is free."
		},
		"loot": [{"id": "gold", "min": 20, "max": 30}, "sharpened-blades"]
	},
	"merchant": {
		"name": "Silas the Sly", "biome": "town",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 40, "gold": 500},
		"dialog": {
			"initial": "Fine wares for a fine price! Don't listen to Silas, he's a thief. Oh wait, I am Silas.",
			"robbed": "You'll regret that, thief!"
		},
		"loot": [{"id": "gold", "min": 100, "max": 300}, "potion"]
	},
	"mayor": {
		"name": "Mayor Sterling", "biome": "town",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 30},
		"dialog_tree": "t15_mayor",
		"dialog": { "initial": "The Forest is becoming dangerous. I cannot let you pass the gate without the Town Seal." },
		"loot": ["town_seal"]
	},
	"innkeeper": {
		"name": "Martha", "biome": "town",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 50},
		"dialog_tree": "t2_tavern",
		"dialog": { "initial": "A warm bed and a cold drink. Keep an eye on Silas, he likes to 'borrow' coins." },
		"loot": ["ale", "bread"]
	},
	"priest": {
		"name": "Father Thomas", "biome": "town",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 45},
		"dialog": { "initial": "I've heard the bells ringing in the Silent Cathedral of the Abyss. Dark times ahead." },
		"loot": ["holy_water"]
	},
	"librarian": {
		"name": "Evelyn", "biome": "town",
		"icon": "res://assets/npc/archivist/base.png",
		"stats": {"hp": 25},
		"dialog": { "initial": "The Void isn't a place, traveler. It's a memory that forgot itself." },
		"loot": ["old_map", "scroll"]
	},
	"stablehand": {
		"name": "Barnaby", "biome": "town",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 40},
		"dialog": { "initial": "The horses won't go near the Ice Caves. They smell the Yeti from miles away." },
		"loot": ["apple", "rope"]
	},
	"guard_captain": {
		"name": "Captain Vane", "biome": "town",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 120, "strength": 20},
		"dialog_tree": "t1_gate_guard",
		"dialog": { "initial": "Halt. No one enters the Forest without the Mayor's permission." },
		"loot": ["iron_shield"]
	},
	"baker": {
		"name": "Oswald", "biome": "town",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 35},
		"dialog": { "initial": "Fresh bread! Even a Stone Golem would crack a tooth for a bite of this." },
		"loot": ["bread", "flour"]
	},
	"beggar": {
		"name": "Old Wat", "biome": "town",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 15},
		"dialog_tree": "t19_beggar",
		"dialog": { "initial": "I once saw the Void Emperor. He looked just like... well, like you." },
		"loot": ["strange_coin"]
	},

	# --- FOREST BIOME ---
	"mystic": {
		"name": "Elowen", "biome": "forest",
		"icon": "res://assets/npc/archivist/base.png",
		"stats": {"hp": 50},
		"dialog_tree": "f3_merchant",
		"dialog": { "initial": "The stars are cold today. They whisper of a key hidden in a desert tomb." },
		"loot": ["moon_essence"]
	},
	"herbalist": {
		"name": "Fauna", "biome": "forest",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 30},
		"dialog": { "initial": "I've been trading herbs with the Swamp Hag. She's cranky, but she knows her brews." },
		"loot": ["healing_herb", "poison_ivy"]
	},
	"woodcutter": {
		"name": "Thrain", "biome": "forest",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 80, "strength": 18},
		"dialog": { "initial": "Don't go near the Elder Oak. It's stopped drinking water and started drinking... other things." },
		"loot": ["bundle_of_wood", "hand_axe"]
	},
	"ranger": {
		"name": "Kael", "biome": "forest",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 70},
		"dialog": { "initial": "I saw a child wander into the Swamp. If you see Mother Bile, tell her to let him go." },
		"loot": ["arrow_bundle", "leather_scraps"]
	},
	"lost_child": {
		"name": "Timmy", "biome": "forest",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 10},
		"dialog": { "initial": "The Hag in the swamp took my rabbit... she said it was for a 'special soup'." },
		"loot": ["lucky_rabbit_foot"]
	},
	"druid": {
		"name": "Elder Rowan", "biome": "forest",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 90},
		"dialog": { "initial": "To survive the Ice Caves, you'll need the Moon Essence Elowen carries." },
		"loot": ["oak_staff"]
	},
	"fey_spirit": {
		"name": "Glimmer", "biome": "forest",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 20},
		"dialog": { "initial": "The King of the Desert is awake! He's grumpy because his crown is dusty!" },
		"loot": ["fairy_dust"]
	},
	"hunter": {
		"name": "Huntsman Jorg", "biome": "forest",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 75},
		"dialog": { "initial": "Looking for the Yeti? Look for the trail of frozen bones." },
		"loot": ["pelt", "dried_meat"]
	},
	"satyr": {
		"name": "Pan", "biome": "forest",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 55},
		"dialog": { "initial": "My pipes are made from Core-wood. Vulcan itself forged the mouth-piece." },
		"loot": ["wooden_flute"]
	},
	"strange_rabbit": {
		"name": "Mr. Whiskers", "biome": "forest",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 5},
		"dialog_tree": "f16_rabbit",
		"dialog": { "initial": "*Wiggles nose at the mention of the Swamp Hag*" },
		"loot": ["clover"]
	},

	# --- ICE CAVES BIOME ---
	"frost_hermit": {
		"name": "Kjell", "biome": "ice_caves",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 60},
		"dialog": { "initial": "The cold doesn't bite if you respect it." },
		"loot": ["frozen_berries"]
	},
	"frozen_explorer": {
		"name": "Sir Alistair", "biome": "ice_caves",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 40},
		"dialog": { "initial": "I... I think my toes are gone. Worth it for the map, though." },
		"loot": ["old_compass"]
	},
	"ice_giant": {
		"name": "Brundle", "biome": "ice_caves",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 500, "strength": 40},
		"dialog": { "initial": "Little thing... why you walk in freezer?" },
		"loot": ["giant_club"]
	},
	"cryomancer": {
		"name": "Lysandra", "biome": "ice_caves",
		"icon": "res://assets/npc/archivist/base.png",
		"stats": {"hp": 65},
		"dialog": { "initial": "Ice is simply water with more discipline." },
		"loot": ["ice_shard", "scroll"]
	},
	"snow_scout": {
		"name": "Erik", "biome": "ice_caves",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 55},
		"dialog": { "initial": "Watch your step. The crevasses here move." },
		"loot": ["climbing_pick"]
	},
	"berg_merchant": {
		"name": "Ol' Salty", "biome": "ice_caves",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 45},
		"dialog": { "initial": "I sell blankets, tea, and very expensive firewood." },
		"loot": ["firewood", "blanket"]
	},
	"ice_sculptor": {
		"name": "Marius", "biome": "ice_caves",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 30},
		"dialog": { "initial": "True beauty is fleeting. It melts by noon." },
		"loot": ["chisel"]
	},
	"polar_guide": {
		"name": "Sanna", "biome": "ice_caves",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 80},
		"dialog": { "initial": "Follow my tracks. Don't wander into the mist." },
		"loot": ["heavy_boots"]
	},
	"ghost_miner": {
		"name": "Miner 49er", "biome": "ice_caves",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 0},
		"dialog": { "initial": "Still lookin' for that silver vein... been a long shift." },
		"loot": ["silver_ore"]
	},
	"yeti_outcast": {
		"name": "Grog", "biome": "ice_caves",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 150},
		"dialog": { "initial": "My brothers are mean. I like humans. Humans smell like meat." },
		"loot": ["white_fur"]
	},

	# --- DESERT BIOME ---
	"nomad_leader": {
		"name": "Zayd", "biome": "desert",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 85},
		"dialog": { "initial": "The sand remembers every footstep. Yours will be forgotten by sunset." },
		"loot": ["scimitar"]
	},
	"oasis_keeper": {
		"name": "Layla", "biome": "desert",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 40},
		"dialog": { "initial": "Water is more precious than gold here. Don't waste a drop." },
		"loot": ["waterskin"]
	},
	"archeologist": {
		"name": "Professor Hurn", "biome": "desert",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 45},
		"dialog": { "initial": "This pillar dates back to the first age! Or it's a very large rock." },
		"loot": ["magnifying_glass"]
	},
	"sand_sailor": {
		"name": "Capt. Dune", "biome": "desert",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 70},
		"dialog": { "initial": "The dunes shift like waves. You need a steady hand at the rudder." },
		"loot": ["silk_sail"]
	},
	"sphinx_npc": {
		"name": "The Riddle-Maker", "biome": "desert",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 1000},
		"dialog": { "initial": "What walks on four legs in the morning... wait, I forgot the rest." },
		"loot": ["ancient_wisdom"]
	},
	"genie_trapped": {
		"name": "Jafarish", "biome": "desert",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 200},
		"dialog": { "initial": "Ten thousand years will give you such a crick in the neck!" },
		"loot": ["magic_lamp"]
	},
	"caravan_cook": {
		"name": "Fatima", "biome": "desert",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 50},
		"dialog": { "initial": "Spices keep the heat away. Try the cumin." },
		"loot": ["spice_pouch"]
	},
	"scorpion_charmer": {
		"name": "Malik", "biome": "desert",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 60},
		"dialog": { "initial": "They only sting if you're afraid. Or if you're delicious." },
		"loot": ["venom_vial"]
	},
	"sun_priest": {
		"name": "Ra-Amun", "biome": "desert",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 90},
		"dialog": { "initial": "The Sun God sees all. Close your eyes, it's safer." },
		"loot": ["solar_disc"]
	},
	"exiled_prince": {
		"name": "Khalid", "biome": "desert",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 110, "strength": 22},
		"dialog": { "initial": "My kingdom is buried under a mile of sand. I intend to dig it up." },
		"loot": ["royal_signet"]
	},

	# --- SWAMP BIOME ---
	"swamp_hag": {
		"name": "Old Mother Bile", "biome": "swamp",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 120},
		"dialog": { "initial": "Need a little luck? I've got some in a jar. It's mostly teeth." },
		"loot": ["jar_of_teeth", "witch_brew"]
	},
	"bog_doctor": {
		"name": "Dr. Quack", "biome": "swamp",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 55},
		"dialog": { "initial": "Leeches are the solution to every problem. Headaches? Leeches. Heartbreak? Leeches." },
		"loot": ["leech_vial"]
	},
	"ferryman": {
		"name": "Charon", "biome": "swamp",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 999},
		"dialog": { "initial": "One coin to cross. Two if you want me to stop humming." },
		"loot": ["oar"]
	},
	"mud_fisher": {
		"name": "Bubba", "biome": "swamp",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 45},
		"dialog": { "initial": "Catfish here are big enough to eat a dog. Best use a strong line." },
		"loot": ["catfish"]
	},
	"frog_folk_elder": {
		"name": "Croak", "biome": "swamp",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 40},
		"dialog": { "initial": "Ribbit... welcome to the lily pad. Don't sink." },
		"loot": ["lily_pad_shield"]
	},
	"swamp_hermit": {
		"name": "Mossy Pete", "biome": "swamp",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 50},
		"dialog": { "initial": "I've lived here so long I'm starting to grow roots." },
		"loot": ["moss_cloak"]
	},
	"reptile_trader": {
		"name": "Slyther", "biome": "swamp",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 65},
		"dialog": { "initial": "Snake skin, alligator teeth, lizard tails! All fresh-ish!" },
		"loot": ["reptile_scale"]
	},
	"bayou_bard": {
		"name": "Banjo Ben", "biome": "swamp",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 40},
		"dialog": { "initial": "*Plucks a sad chord* The mosquitoes provide the backup vocals." },
		"loot": ["banjo"]
	},
	"sunken_ghost": {
		"name": "Lost Soldier", "biome": "swamp",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 0},
		"dialog": { "initial": "Is the war over? My armor is so heavy now." },
		"loot": ["rusty_medal"]
	},
	"swamp_alchemist": {
		"name": "Vex", "biome": "swamp",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 70},
		"dialog": { "initial": "Gas from the bog is highly flammable. Watch your torch." },
		"loot": ["gas_bomb"]
	},

	# --- ABYSS BIOME ---
	"deep_diver": {
		"name": "Commander Nemo", "biome": "abyss",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 110},
		"dialog": { "initial": "My suit is the only thing keeping me from becoming a pancake." },
		"loot": ["brass_helmet"]
	},
	"mermaid": {
		"name": "Arielis", "biome": "abyss",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 80},
		"dialog": { "initial": "Up on the shore they work all day... glad I'm down here." },
		"loot": ["sea_shell"]
	},
	"coral_king": {
		"name": "Neptos", "biome": "abyss",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 300, "strength": 35},
		"dialog": { "initial": "The Abyss is my kingdom. You are merely a bubble passing through." },
		"loot": ["trident"]
	},
	"pearl_seeker": {
		"name": "Mina", "biome": "abyss",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 55},
		"dialog": { "initial": "One more giant clam and I'm retiring to the surface." },
		"loot": ["black_pearl"]
	},
	"ancient_naga": {
		"name": "Sssar", "biome": "abyss",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 150},
		"dialog": { "initial": "I remember when this place was a mountain. Time is wet." },
		"loot": ["naga_scale"]
	},
	"submariner": {
		"name": "Pilot Jack", "biome": "abyss",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 60},
		"dialog": { "initial": "Engine's leaking, hull's creaking, and the sonar's speaking nonsense." },
		"loot": ["wrench"]
	},
	"sea_hag": {
		"name": "Barnacle Barb", "biome": "abyss",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 95},
		"dialog": { "initial": "Salt water cures everything. Except death. Death is very salty." },
		"loot": ["kelp_potion"]
	},
	"drowned_poet": {
		"name": "Byron", "biome": "abyss",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 0},
		"dialog": { "initial": "The ink runs thin in the crushing dark." },
		"loot": ["wet_journal"]
	},
	"trench_merchant": {
		"name": "Barnaby the Bottom", "biome": "abyss",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 70},
		"dialog": { "initial": "I trade in sunken gold and very flat fish." },
		"loot": ["gold_bar"]
	},
	"jelly_whisperer": {
		"name": "Lumi", "biome": "abyss",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 45},
		"dialog": { "initial": "They don't sting if you hum at a low frequency." },
		"loot": ["glow_gel"]
	},

	# --- VOID BIOME ---
	"void_trader": {
		"name": "The Unmaker", "biome": "void",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 500},
		"dialog": { "initial": "I trade things that were for things that might be." },
		"loot": ["void_essence"]
	},
	"past_self": {
		"name": "A Familiar Face", "biome": "void",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 100},
		"dialog": { "initial": "You look like you're having a bad day. Trust me, it gets weirder." },
		"loot": ["memory_fragment"]
	},
	"time_keeper": {
		"name": "Chronos", "biome": "void",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 1000},
		"dialog": { "initial": "You're five minutes early. Or late. Time is a messy eater." },
		"loot": ["broken_watch"]
	},
	"star_gazer": {
		"name": "Nova", "biome": "void",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 60},
		"dialog": { "initial": "The stars aren't points of light; they're holes in the curtain." },
		"loot": ["stardust"]
	},
	"fragmented_mind": {
		"name": "Subject 0", "biome": "void",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 40},
		"dialog": { "initial": "Zero. One. Zero. One. Help. One. Zero." },
		"loot": ["binary_key"]
	},
	"paradox_merchant": {
		"name": "The Seller of Secrets", "biome": "void",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 80},
		"dialog": { "initial": "I'll sell you this sword yesterday for the price of tomorrow." },
		"loot": ["echo_blade"]
	},
	"null_priest": {
		"name": "Voidwalker", "biome": "void",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 150},
		"dialog": { "initial": "Silence is the only true prayer." },
		"loot": ["dark_tome"]
	},
	"memory_thief": {
		"name": "The Forgetter", "biome": "void",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 90},
		"dialog": { "initial": "What were we talking about? Exactly." },
		"loot": ["stolen_memory"]
	},
	"rift_scientist": {
		"name": "Dr. Strange", "biome": "void",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 75},
		"dialog": { "initial": "The math says you shouldn't exist. Fascinating." },
		"loot": ["lab_notes"]
	},
	"last_soul": {
		"name": "The End", "biome": "void",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 10},
		"dialog": { "initial": "Turn off the lights when you leave." },
		"loot": ["final_tear"]
	},

	# --- THE CORE BIOME ---
	"legendary_smith": {
		"name": "Vulcan", "biome": "the_core",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 2000, "strength": 100},
		"dialog": { "initial": "My apprentice Grimbald is a good lad, but he lacks the heat. You want the Titan Hammer? You'll find it in the Abyss." },
		"loot": ["titan_hammer"]
	},
	"magma_miner": {
		"name": "Rocky", "biome": "the_core",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 150, "strength": 30},
		"dialog": { "initial": "Digging for diamonds, finding mostly fire." },
		"loot": ["magma_ore"]
	},
	"steam_engineer": {
		"name": "Watt", "biome": "the_core",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 80},
		"dialog": { "initial": "The pressure is climbing. One wrong turn and we're all whistle-fodder." },
		"loot": ["steam_gauge"]
	},
	"heat_shaman": {
		"name": "Igneous", "biome": "the_core",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 130},
		"dialog": { "initial": "The Core has a heartbeat. It's getting faster." },
		"loot": ["fire_totem"]
	},
	"core_surveyor": {
		"name": "Mapper Mark", "biome": "the_core",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 70},
		"dialog": { "initial": "The center of the world is slightly to the left." },
		"loot": ["heat_map"]
	},
	"obsidian_artist": {
		"name": "Glass-Man", "biome": "the_core",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 50},
		"dialog": { "initial": "I carve statues out of volcanic glass. Very sharp, very dangerous." },
		"loot": ["obsidian_statue"]
	},
	"pressure_mechanic": {
		"name": "Fix-it Felix", "biome": "the_core",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 90},
		"dialog": { "initial": "If it ain't glowing, it ain't hot enough." },
		"loot": ["heat_resistant_wrench"]
	},
	"fire_dancer": {
		"name": "Blaze", "biome": "the_core",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 110},
		"dialog": { "initial": "Watch the step! One slip and you're part of the floor." },
		"loot": ["burning_fan"]
	},
	"elemental_emissary": {
		"name": "Sulfur", "biome": "the_core",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 180},
		"dialog": { "initial": "The Fire Lord is busy. Leave a message with the ashes." },
		"loot": ["sulfur_gem"]
	},
	"foundry_overseer": {
		"name": "Master Burner", "biome": "the_core",
		"icon": "res://assets/npc/base.png",
		"stats": {"hp": 250},
		"dialog": { "initial": "Quotas must be met! The world doesn't heat itself!" },
		"loot": ["overseer_whip"]
	}
}

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

const CARDS = {
	"strike": {"name": "Strike", "type": "attack", "value": 6, "cost": 1, "icon": "res://assets/sword.png", "desc": "Deal 6 damage."},
	"block": {"name": "Defend", "type": "skill", "value": 5, "cost": 1, "icon": "res://assets/shield.png", "desc": "Gain 5 Block."}
}

const ITEMS = {
	"bandage": {"name": "Clean Bandage", "desc": "Stop bleeding.", "icon": "res://assets/bandage.png"},
	"potion": {"name": "Healing Potion", "desc": "Restore 15 HP.", "icon": "res://assets/potion.png"},
	"gold": {"name": "Gold Coins", "desc": "Currency for shops.", "icon": "res://assets/heart.png"},
	"skull": {"name": "Bleached Skull", "desc": "A grim trophy.", "icon": "res://assets/skull.png"},
	"frost": {"name": "Ice Essence", "desc": "Cold to the touch.", "icon": "res://assets/frost.png"},
	"honey": {"name": "Sticky Honey", "desc": "Sweet and medicinal.", "icon": "res://assets/potion.png"},
	"scroll": {"name": "Ancient Scroll", "desc": "Contains fading knowledge.", "icon": "res://assets/scroll.png"},
	"axe": {"name": "Heavy Axe", "desc": "A brutal weapon.", "icon": "res://assets/axe.png"}
}

# --- VISUAL ASSET MAPPING ---
const ICON_MAP = {
	"home": "res://assets/maps/home.png",
	"battle": "res://assets/sword.png",
	"shop": "res://assets/key.png",
	"rest": "res://assets/heart.png",
	"event": "res://assets/scroll.png",
	"lore": "res://assets/scroll.png", # Using scroll for lore NPCs
	"trap": "res://assets/trap.png",
	"boss": "res://assets/skull.png",
	"mystery": "res://assets/mystery.png" # Updated mystery asset
}
