# Testing Memoria

To maintain a "Premium" feel for the Steam release, we use three levels of testing.

1. Unit Testing (Logic)

* Focus: Math, Data Parsing, Signal flow.
* Tool: GUT (Godot Unit Test).
* Location: res://test/unit/.
* Run: Open the GUT panel in Godot and click "Run All".

Use these for CombatManager math.
Use these to ensure MapGenerator doesn't create unreachable nodes.

2. Integration Testing (Scenes)

* Focus: UI Layouts, Card Flipping, Animations.
* Method: DebugBootstrapper.gd.
* Workflow:

Open res://core/DebugBootstrapper.gd.
Uncomment the "Test Case" you want to see.
In Godot Project Settings, change the Main Run Scene to DebugBootstrapper.tscn.
Press F5. You will skip the menu and launch directly into the specific combat or event scenario.


3. Asset Auditing (Resources)

Focus: Missing files, broken paths.
Tool: .notes/asset_audit.py.
Run: python3 .notes/asset_audit.py.

Run this before every commit to ensure you haven't forgotten to create a *.tres file for a new room ID.


4. Cheat Console (Optional Integration)

If you want to test "live," add this to GameManager.gd:

```
func _input(event):
    if OS.is_debug_build() and event is InputEventKey:
        if event.pressed and event.keycode == KEY_K:
            current_hp = 0 # Instant death test
        if event.pressed and event.keycode == KEY_G:
            gold += 100 # Economy test
```

5. E2E Testing

Limited release for game testers & feedback 