Memory Dungeon: Steam Production Roadmap

1. Game Functions: Data & Systems

Core technical infrastructure for a commercial release.

[ ] Save/Load System:
	[ ] Implement a SaveManager.gd using Godot's FileAccess (JSON or ConfigFile).
	[ ] Track "Meta-Progression" (Shards, Unlocked Cards, High Scores).
	[ ] Track "Mid-Run" saves (Current Floor, HP, Deck, Relics) for crash protection.

[ ] Steam Integration:
	[ ] Integrate GodotSteam or SteamTools GDExtension.
	[ ] Set up Steam Cloud Saves.
	[ ] Implement Steam Achievements (e.g., "Matched 10 Traps," "Flawless Boss Victory").

[ ] Settings & Configuration:
	[ ] Resolution/Window scaling (Laptop vs. Ultra-wide).
	[ ] Master/SFX/Music volume sliders.
	[ ] Keybinding remaps (Controller and Keyboard).

2. Graphics: Assets & Identity

Transforming placeholders into a cohesive brand.

[ ] The Cards:

[ ] Card Backs: Unique designs for different dungeon zones (Cave, Castle, Abyss).

[ ] Icon Set: High-resolution 2D illustrations replacing emojis (Sword, Shield, etc.).

[ ] Card Frames: Distinct borders for Rarity (Common, Rare, Legendary) and Type (Attack, Heal, Curse).

[ ] The Characters:

[ ] Player Avatars: 3-5 unique heroes with idle animations (Archivist, Berserker, etc.).

[ ] Enemies: 10+ unique monsters with "Intent" animations (Preparing Attack, Charging, Guarding).

[ ] Bosses: Massive, multi-tile entities with unique screen-filling effects.

3. Scenes: Exploration & Deckbuilding

Moving beyond a single battle scene.

[ ] World Scene (The Overworld):

[ ] Node-based map generation (similar to Slay the Spire).

[ ] Character movement between nodes (Battle, Event, Shop, Campfire).

[ ] Fog of War mechanics (players only see 1-2 steps ahead).

[ ] The Armory (Character Scene):

[ ] "Select Cards" UI: Choose a starting deck before the run begins.

[ ] Inventory View: See current relics, active passive buffs, and collected memory shards.

[ ] Deck Editing: Remove "Basic" cards or upgrade them at shop nodes.

4. Storyline: Progression & Narrative

Keeping the player engaged for 100+ hours.

[ ] Character Progression:

[ ] XP System: Earn experience after every run to level up the "Account."

[ ] Unlocks: New levels unlock more complex cards and tougher enemy types.

[ ] Skill Trees: Permanent stat boosts (e.g., "+5 Starting HP," "10% chance to not consume a peek charge").

[ ] The Lore:

[ ] Intro text for each Dungeon Floor describing the "Memory Corruption."

[ ] Random Narrative Events: Non-combat encounters where players make choices (e.g., "Trade 10 Max HP for a Rare Card").

5. Video: Cinematic Experience

Professional polish for the Steam store and player immersion.

[ ] Intro Roll (The Hook):

[ ] 30-second animated sequence explaining the "Memory Loss" of the protagonist.

[ ] Logo reveal with sound design.

[ ] Mid-Run Cinematics:

[ ] Short transitions when changing "Acts" (moving from Level 3 to 4, etc.).

[ ] Visual stingers when a Boss appears.

[ ] End Roll (The Resolution):

[ ] "Victory" cinematic for completing the final level.

[ ] Credit sequence featuring unlockable art pieces from development.

6. Steam Store & Marketing

[ ] Steam Page Assets: Header image, capsule art, and 5 distinct screenshots.

[ ] Trailer: 1-minute gameplay trailer focusing on the "Match-to-Attack" loop and high-speed memory combos.

[ ] Demo: Polished 2-level demo for Steam Next Fest.