# Project Action List: Memoria Evolution
---
## Storyline

* [ ] High Level 

## 🎨 Asset Production

### Icons (80x80)
* [x] Create `home`, `battle`, `shop`, `rest`, `event`, `boss`, `mystery`.

### Biome Environments (180x180)

0. The Shallows (Seriphos)
    Visual: A quiet, misty coastline with unnaturally still, mirror-like water and shipwrecks.
    Keywords: Mist, Calm, Reflections, Rust, Lullabies.

1. Town ... 

2. Whispering Woods (Ethiops)
    Visual: A dense, dark forest of petrified trees frozen in agony. Smells of salt and rot.
    Keywords: Petrified Wood, Shadows, Decay, Coastal Clearing.

3. The Caverns (Graeae)
    Visual: A subterranean network of absolute darkness. No natural light; walls echo with overlapping voices.
    Keywords: Pitch Black, Echoes, Subterranean, Quartz, Sensory.

4. Floating Gardens (Hesperides)
    Visual: An orchard of glowing flora floating in a perpetual sunset. Weak gravity and shimmering ichor.
    Keywords: Sunset, Bioluminescence, Low-Gravity, Gold, Orchard.

5. Gorgon’s Peak
    Visual: A volcanic mountain made of obsidian and glass. Every surface acts as a mirror.
    Keywords: Obsidian, Glass, Mirrors, Volcanic, Psychological.

6. The Petrified Hall (Argos)
    Visual: A frozen, regal palace filled with hundreds of statues of terrified courtiers.
    Keywords: Marble, Frozen, Palace, Ruin, Statues.

7. Sky-Pillar Plateau (Atlas)
    Visual: A desolate, thin-aired peak where stars burn bright enough to scorch the earth.
    Keywords: Desolate, Stars, Altitude, Living Rock, Astral.

8. The Memory Well (Mnemosyne)
    Visual: A cosmic void of liquid silver and floating memories. Physics and geometry are broken.
    Keywords: Liquid Silver, Void, Timeless, Spectral, Reality-Warp.
    

* Simple - generic images (~4)  
    * [] `town`: ...
    * [x] `forest`: Overgrown, greens, woods.
    * [ ] `ice_caves`: Frozen, blues, crystals.
    * [ ] `desert`: Sandy, yellow, ruins.
    * [ ] `swamp`: Murky, dark greens, water.
    * [ ] `abyss`: Deep cave, dark purple/grey.
    * [ ] `void`: Cosmic, black, ethereal.
    * [ ] `the_core`: Final zone.

* Detailed - per room 
    * [] `town`: ...
    * [ ] `forest`: Overgrown, greens, woods.
    * [ ] `ice_caves`: Frozen, blues, crystals.
    * [ ] `desert`: Sandy, yellow, ruins.
    * [ ] `swamp`: Murky, dark greens, water.
    * [ ] `abyss`: Deep cave, dark purple/grey.
    * [ ] `void`: Cosmic, black, ethereal.
    * [ ] `the_core`: Final zone.
    * [ ] **Dynamic Naming Export:** Generate naming convention files (e.g., `forest_battle_0.png`).

### Characters & NPCs

* [ ] Create base character: `res://assets/character/base.png`.
* [ ] Generate 10 NPCs per biome (GIF or static image per NPC).

### Card UI

* [ ] Design card backs and simple icons.
* [ ] Improve "look and feel" to match *Memoria* aesthetic.

---

## 🗺️ World Map & Navigation

* [ ] **Persistence:** Update generator so map is unique per run and generated only once.
* [ ] **Biomes:** - [ ] Set encounter frequencies (e.g., Town = 10% battle).
* [ ] Update routing and create "connector" images.


* [ ] **Home Base:** Implement player home linking to bottom-center of the map.
* [ ] **Movement & Fog of War:**
* [ ] Implement Fog of War (hide unvisited connections).
* [ ] Highlight current node and allow movement only to connected nodes.
* [ ] Ensure player location updates even if a room has no event.


* [ ] **Camera:** Center/Focus canvas on player icon during load and movement.

---

## ⚔️ Combat System

* [ ] **Visual Overhaul:** - [ ] Top-half 2D side-on environment.
* [ ] Character and enemies face each other.
* [ ] HP bars floating above heads.


* [ ] **Deck Mechanics:**
* [ ] Implement base set: `Attack`, `Heal`, `Armor`, `Trap`.
* [ ] Implement "Discover New" and deck tailoring.
* [ ] **Rule:** Require  in deck based on progress scaling.
* [ ] **Reshuffle Logic:** When only debuffs remain, reshuffle deck.


* [ ] **Class Abilities:** Implement specific functions for `Librarian`, `Athlete`, etc.
* [ ] **Flee Option:** Track last node visited; return player there on flee.
* [ ] **Dev Tools:** Add "Win" button to battle scene for rapid testing.

---

## 🛠️ Systems & Data

* [ ] **JSON Architecture:**
* [ ] Create structure for Dialogue.
* [ ] Create structure for Room Behavior (conditional on game state).


* [ ] **Game State Tracking:**
* [ ] **NPCs:** Track `interacted`, `win_count`, `loss_count`.
* [ ] **Map:** Track `visited` status per biome/node.


* [ ] **Save/Load:** - [ ] Implement "Save & Exit" with confirmation.
* [ ] Implement "Abandon Run" (deletes save).
* [ ] **Loss Loop:** On death, delete save and restart at Home.



---

## 🖥️ UI / UX

* [ ] **Main Menu:** Settings update—apply Fullscreen immediately on toggle.
* [ ] **Character Screen:** - [ ] Display player and full deck (all cards face up).
* [ ] Integrate dictionary/glossary.


* [ ] **Dialog System:** Implement pre-battle dialogue with branching options.
* [ ] **Run Summary:** Create "Wake up at home" transition and Win Condition (Final Boss) scene.
* [ ] **Character Selection:** Improve general UI flow.

---

> **Next Step:** Would you like me to draft the **JSON structure** for the dialogue and room behavior systems so you can begin plugging in your NPC data?