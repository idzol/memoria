# AI Context: Memory Dungeon

## 🛠 Tech Stack
- **Engine:** Godot 4.x
- **Language:** GDScript
- **Architecture:** Feature-based Refactor (Core/Features/Data/Assets)

## 📝 Coding Conventions
- Use `class_name` for types to enable IDE-like autocompletion in prompts.
- Prefer Signal-based communication for decoupled features.
- Standard: `snake_case` for variables/functions, `PascalCase` for classes.
- Pathing: Use `res://` absolute paths for resources.

## 🚀 Global Singletons (Autoloads)
- None defined.

## 🧩 Registered Global Classes
- CardAssetData (at .\data\resources\CardAssetData.gd)
- CardData (at .\data\resources\CardData.gd)
- CardDatabase (at .\core\CardData.gd)
- CardDatabase (at .\core\_CardDatabase.gd)
- EnemyData (at .\data\resources\EnemyData.gd)
- GutErrorTracker (at .\addons\gut\error_tracker.gd)
- GutHookScript (at .\addons\gut\hook_script.gd)
- GutInputFactory (at .\addons\gut\input_factory.gd)
- GutInputSender (at .\addons\gut\input_sender.gd)
- GutMain (at .\addons\gut\gut.gd)
- GutStringUtils (at .\addons\gut\strutils.gd)
- GutTest (at .\addons\gut\test.gd)
- GutTrackedError (at .\addons\gut\gut_tracked_error.gd)
- GutUtils (at .\addons\gut\utils.gd)
- ItemData (at .\data\resources\ItemData.gd)
- MapAssetData (at .\data\resources\MapAssetData.gd)
- NPCData (at .\data\resources\NPCData.gd)
- PlayerData (at .\data\resources\PlayerData.gd)
- RoomData (at .\data\resources\RoomData.gd)
- UIAssetData (at .\data\resources\UIAssetData.gd)

## 📂 Key Directories
- `/core`: Essential engine systems (Managers, Base Classes).
- `/features`: Modular gameplay elements.
- `/data`: Resource files (.tres) and data definitions.
