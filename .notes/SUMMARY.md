# Memory Dungeon: Project Summary

Generated automatically for AI context and debugging.

## /assets
```text
    🖼️ axe.png
    🖼️ axe.png.import
    🖼️ back1.png
    🖼️ back1.png.import
    🖼️ back2.png
    🖼️ back2.png.import
    🖼️ bandage.png
    🖼️ bandage.png.import
    🖼️ bomb.png
    🖼️ bomb.png.import
    🖼️ dagger.png
    🖼️ dagger.png.import
    🖼️ frost.png
    🖼️ frost.png.import
    🖼️ heart.png
    🖼️ heart.png.import
    🖼️ key.png
    🖼️ key.png.import
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
    🖼️ skull.png
    🖼️ skull.png.import
    🖼️ sword.png
    🖼️ sword.png.import
    🖼️ trap.png
    🖼️ trap.png.import
    🖼️ wall.png
    🖼️ wall.png.import
    📂 cards/
    📂 character/
        📂 archivist/
            🖼️ attack.png
            🖼️ attack.png.import
            🖼️ base.png
            🖼️ base.png.import
            🖼️ damage.png
            🖼️ damage.png.import
    📂 maps/
        🖼️ home.png
        🖼️ home.png.import
        🖼️ ice.png
        🖼️ ice.png.import
        🖼️ sand.png
        🖼️ sand.png.import
    📂 npcs/
    📂 rooms/
```

## /scenes
```text
    📂 combat/
        🎬 BattleScene.tscn
        🎬 Card.tscn
        🎬 VictoryScreen.tscn
    📂 encounters/
        🎬 EventScene.tscn
        🎬 LoreScene.tscn
        🎬 RestScene.tscn
        🎬 ShopScene.tscn
        🎬 TrapsScene.tscn
    📂 map/
        🎬 MapNode.tscn
        🎬 WorldMap.tscn
    📂 ui/
        🎬 CardDiscoveryPopup.tscn
        🎬 CharacterScreen.tscn
        🎬 CharacterSelect.tscn
        🎬 DeathScreen.tscn
        🎬 InGameMenu.tscn
        🎬 MainMenu.tscn
        🎬 RunSummary.tscn
        🎬 SettingsOverlay.tscn
```

## /scripts
```text
    📂 core/
        📜 GameManager.gd
        📜 SaveManager.gd
        📜 SignalBus.gd
    📂 data/
        📜 GameData.gd
    📂 logic/
        📜 CombatManager.gd
        📜 MapGenerator.gd
    📂 ui/
        📜 CardDiscoveryPopup.gd
        📜 CharacterScreen.gd
        📜 CharacterSelect.gd
        📜 DeathScreen.gd
        📜 InGameMenu.gd
        📜 MainMenu.gd
        📜 RunSummary.gd
        📜 Settings.gd
        📂 combat/
            📜 BattleScene.gd
            📜 Card.gd
            📜 VictoryScreen.gd
        📂 encounters/
            📜 EventScene.gd
            📜 LoreScene.gd
            📜 RestScene.gd
            📜 ShopScene.gd
            📜 TrapScene.gd
        📂 map/
            📜 MapNode.gd
            📜 WorldMapUI.gd
```

## 🔗 Scene-to-Script Mapping
| Scene (.tscn) | Script (.gd) | Description |
| :--- | :--- | :--- |
| BattleScene.tscn | /scripts/ui/combat/BattleScene.gd | Auto-detected |
| Card.tscn | /scripts/ui/combat/Card.gd | Auto-detected |
| VictoryScreen.tscn | /scripts/ui/combat/VictoryScreen.gd | Auto-detected |
| EventScene.tscn | N/A | Auto-detected |
| LoreScene.tscn | /scripts/ui/encounters/LoreScene.gd | Auto-detected |
| RestScene.tscn | /scripts/ui/encounters/RestScene.gd | Auto-detected |
| ShopScene.tscn | /scripts/ui/encounters/ShopScene.gd | Auto-detected |
| TrapsScene.tscn | /scripts/ui/encounters/TrapScene.gd | Auto-detected |
| MapNode.tscn | /scripts/ui/map/MapNode.gd | Auto-detected |
| WorldMap.tscn | /scripts/ui/map/WorldMapUI.gd | Auto-detected |
| CardDiscoveryPopup.tscn | /scripts/ui/CardDiscoveryPopup.gd | Auto-detected |
| CharacterScreen.tscn | /scripts/ui/CharacterScreen.gd | Auto-detected |
| CharacterSelect.tscn | /scripts/ui/CharacterSelect.gd | Auto-detected |
| DeathScreen.tscn | /scripts/ui/DeathScreen.gd | Auto-detected |
| InGameMenu.tscn | /scripts/ui/InGameMenu.gd | Auto-detected |
| MainMenu.tscn | /scripts/ui/MainMenu.gd | Auto-detected |
| RunSummary.tscn | /scripts/ui/RunSummary.gd | Auto-detected |
| SettingsOverlay.tscn | /scripts/ui/Settings.gd | Auto-detected |
