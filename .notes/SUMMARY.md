# Memory Dungeon: Project Summary

Generated automatically for AI context and debugging.

## /core
```text
    📜 CardDatabase.gd
    📜 DebugBootstrap.gd
    📜 GameData.gd
    📜 GameManager.gd
    📜 SaveManager.gd
    📜 SignalBus.gd
```

## /data
```text
    📂 cards/
        💎 fist.tres
        💎 sword.tres
    📂 enemies/
        💎 pickpocket.tres
        💎 slime.tres
    📂 resources/
        📜 CardData.gd
        📜 EnemyData.gd
        📜 RoomData.gd
    📂 rooms/
        💎 default_battle.tres
        📂 forest/
            💎 f1.tres
        📂 town/
            💎 t1.tres
```

## /features
```text
    📂 combat/
        📜 BattleScene.gd
        🎬 BattleScene.tscn
        📜 Card.gd
        🎬 Card.tscn
        📜 CombatManager.gd
        📜 VictoryScreen.gd
        🎬 VictoryScreen.tscn
    📂 encounters/
        📜 EventScene.gd
        🎬 EventScene.tscn
        📜 LoreScene.gd
        🎬 LoreScene.tscn
        📜 RestScene.gd
        🎬 RestScene.tscn
        📜 ShopScene.gd
        🎬 ShopScene.tscn
        📜 TrapScene.gd
        🎬 TrapsScene.tscn
    📂 map/
        📜 MapGenerator.gd
        📜 MapNode.gd
        🎬 MapNode.tscn
        🎬 WorldMap.tscn
        📜 WorldMapUI.gd
    📂 ui/
        📜 CardDiscoveryPopup.gd
        🎬 CardDiscoveryPopup.tscn
        📜 CharacterScreen.gd
        🎬 CharacterScreen.tscn
        📜 CharacterSelect.gd
        🎬 CharacterSelect.tscn
        📜 ControlsMenu.gd
        🎬 ControlsMenu.tscn
        📜 Credits.gd
        🎬 Credits.tscn
        📜 DeathScreen.gd
        🎬 DeathScreen.tscn
        📜 InGameMenu.gd
        🎬 InGameMenu.tscn
        📜 IntroCinematic.gd
        🎬 IntroCinematic.tscn
        📜 MainMenu.gd
        🎬 MainMenu.tscn
        📜 RunSummary.gd
        🎬 RunSummary.tscn
        📜 Settings.gd
        🎬 SettingsOverlay.tscn
```

## /assets
```text
    📂 card/
        🖼️ axe.png
        🖼️ axe.png.import
        🖼️ back1.png
        🖼️ back1.png.import
        🖼️ back2.png
        🖼️ back2.png.import
        🖼️ bandage.png
        🖼️ bandage.png.import
        🖼️ block.png
        🖼️ block.png.import
        🖼️ bomb.png
        🖼️ bomb.png.import
        🖼️ dagger.png
        🖼️ dagger.png.import
        🖼️ fireball.png
        🖼️ fireball.png.import
        🖼️ fist.png
        🖼️ fist.png.import
        🖼️ frost.png
        🖼️ frost.png.import
        🖼️ heart.png
        🖼️ heart.png.import
        🖼️ key.png
        🖼️ key.png.import
        🖼️ kick.png
        🖼️ kick.png.import
        🖼️ lightning.png
        🖼️ lightning.png.import
        🖼️ potion.png
        🖼️ potion.png.import
        🖼️ scroll.png
        🖼️ scroll.png.import
        🖼️ sharpened-blades.png
        🖼️ sharpened-blades.png.import
        🖼️ shield.png
        🖼️ shield.png.import
        🖼️ shield_gold.png
        🖼️ shield_gold.png.import
        🖼️ skull.png
        🖼️ skull.png.import
        🖼️ sword.png
        🖼️ sword.png.import
        🖼️ sword_gold.png
        🖼️ sword_gold.png.import
        🖼️ trap.png
        🖼️ trap.png.import
        🖼️ trap_spike.png
        🖼️ trap_spike.png.import
        🖼️ wall.png
        🖼️ wall.png.import
        📂 icon/
            🖼️ axe.png
            🖼️ axe.png.import
            🖼️ back1.png
            🖼️ back1.png.import
            🖼️ back2.png
            🖼️ back2.png.import
            🖼️ bandage.png
            🖼️ bandage.png.import
            🖼️ block.png
            🖼️ block.png.import
            🖼️ bomb.png
            🖼️ bomb.png.import
            🖼️ dagger.png
            🖼️ dagger.png.import
            🖼️ fireball.png
            🖼️ fireball.png.import
            🖼️ fist.png
            🖼️ fist.png.import
            🖼️ frost.png
            🖼️ frost.png.import
            🖼️ heart.png
            🖼️ heart.png.import
            🖼️ key.png
            🖼️ key.png.import
            🖼️ kick.png
            🖼️ kick.png.import
            🖼️ lightning.png
            🖼️ lightning.png.import
            🖼️ potion.png
            🖼️ potion.png.import
            🖼️ scroll.png
            🖼️ scroll.png.import
            🖼️ sharpened-blades.png
            🖼️ sharpened-blades.png.import
            🖼️ shield.png
            🖼️ shield.png.import
            🖼️ shield_gold.png
            🖼️ shield_gold.png.import
            🖼️ skull.png
            🖼️ skull.png.import
            🖼️ sword.png
            🖼️ sword.png.import
            🖼️ sword_gold.png
            🖼️ sword_gold.png.import
            🖼️ trap.png
            🖼️ trap.png.import
            🖼️ trap_spike.png
            🖼️ trap_spike.png.import
            🖼️ wall.png
            🖼️ wall.png.import
    📂 enemy/
        🖼️ base.png
        🖼️ base.png.import
    📂 fonts/
        🖼️ Forum-Regular.ttf.import
        🖼️ minotaur.ttf.import
    📂 maps/
        🖼️ default.png
        🖼️ default.png.import
        🖼️ forest_0.png
        🖼️ forest_0.png.import
        🖼️ forest_1.png
        🖼️ forest_1.png.import
        🖼️ forest_2.png
        🖼️ forest_2.png.import
        🖼️ forest_3.png
        🖼️ forest_3.png.import
        🖼️ home.png
        🖼️ home.png.import
        🖼️ ice.png
        🖼️ ice.png.import
        🖼️ sand.png
        🖼️ sand.png.import
        📂 icon/
            🖼️ battle.png
            🖼️ battle.png.import
            🖼️ event.png
            🖼️ event.png.import
            🖼️ home.png
            🖼️ home.png.import
            🖼️ mystery.png
            🖼️ mystery.png.import
            🖼️ rest.png
            🖼️ rest.png.import
            🖼️ shop.png
            🖼️ shop.png.import
            🖼️ sword.png
            🖼️ sword.png.import
    📂 music/
        🖼️ amb_100.ogg.import
        🖼️ mus_100.ogg.import
    📂 npc/
    📂 player/
    📂 rooms/
        🖼️ default.png
        🖼️ default.png.import
    📂 sfx/
    📂 themes/
    📂 ui/
        🖼️ end_day_1.png
        🖼️ end_day_1.png.import
        🖼️ end_day_2.png
        🖼️ end_day_2.png.import
        🖼️ end_day_3.png
        🖼️ end_day_3.png.import
        🖼️ main_background.png
        🖼️ main_background.png.import
    📂 video/
```

## 🔗 Scene-to-Script Mapping
| Scene (.tscn) | Script (.gd) | Location |
| :--- | :--- | :--- |
| BattleScene.tscn | /features/combat/BattleScene.gd | features\combat |
| Card.tscn | /features/combat/Card.gd | features\combat |
| VictoryScreen.tscn | /features/combat/VictoryScreen.gd | features\combat |
| EventScene.tscn | N/A | features\encounters |
| LoreScene.tscn | /features/encounters/LoreScene.gd | features\encounters |
| RestScene.tscn | /features/encounters/RestScene.gd | features\encounters |
| ShopScene.tscn | /features/encounters/ShopScene.gd | features\encounters |
| TrapsScene.tscn | /features/encounters/TrapScene.gd | features\encounters |
| MapNode.tscn | /features/map/MapNode.gd | features\map |
| WorldMap.tscn | /features/map/WorldMapUI.gd | features\map |
| CardDiscoveryPopup.tscn | /features/ui/CardDiscoveryPopup.gd | features\ui |
| CharacterScreen.tscn | /features/ui/CharacterScreen.gd | features\ui |
| CharacterSelect.tscn | /features/ui/CharacterSelect.gd | features\ui |
| ControlsMenu.tscn | /features/ui/ControlsMenu.gd | features\ui |
| Credits.tscn | /features/ui/Credits.gd | features\ui |
| DeathScreen.tscn | /features/ui/DeathScreen.gd | features\ui |
| InGameMenu.tscn | /features/ui/InGameMenu.gd | features\ui |
| IntroCinematic.tscn | /features/ui/IntroCinematic.gd | features\ui |
| MainMenu.tscn | /features/ui/MainMenu.gd | features\ui |
| RunSummary.tscn | /features/ui/RunSummary.gd | features\ui |
| SettingsOverlay.tscn | /features/ui/Settings.gd | features\ui |
