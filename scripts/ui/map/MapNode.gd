extends Control

# res://scripts/ui/MapNode.gd
# Visual representation of a single location on the world map.

signal node_clicked(data)

@onready var button = $Button
@onready var icon_label = $Button/Icon
@onready var border = $Border
@onready var player_icon = %PlayerIcon 

var node_data = null

func setup_advanced(data, color, is_revealed, is_reachable, is_player_here):
    # 1. Handle Fog of War
    if !is_revealed:
        modulate = Color(0.2, 0.2, 0.2, 0.8) # Darkened
        $Icon.visible = false
    else:
        modulate = Color.WHITE
        $Icon.visible = true
        # 2. Assign Correct Icon based on type
        var icon_path = "res://assets/maps/sword.png" # Default
        match data.type:
            "home": icon_path = "res://assets/maps/home.png"
            "town": icon_path = "res://assets/maps/ice.png" # Or town asset
            "event": icon_path = "res://assets/maps/scroll.png"
        $Icon.texture = load(icon_path)
    
    # 3. Handle Player Indicator (The "Avatar")
    $PlayerIndicator.visible = is_player_here
    
    # 4. Interaction Highlight
    if is_reachable:
        $SelectionPulse.play("available")
    else:
        $SelectionPulse.stop()

func setup_advanced(data, color, is_revealed, is_reachable, is_player_here):
    # 1. Handle Fog of War
    if !is_revealed:
        modulate = Color(0.1, 0.1, 0.1, 0.9) # Much darker fog
        $Icon.visible = false
    else:
        modulate = Color.WHITE
        $Icon.visible = true
        
        # 2. Assign Correct Icon based on type
        # Defaulting to a question mark or skull if type is unknown
        var icon_path = "res://assets/skull.png" 
        
        match data.type:
            "home": 
                icon_path = "res://assets/maps/home.png"
            "town": 
                icon_path = "res://assets/maps/ice.png"
            "battle":
                icon_path = "res://assets/sword.png"
            "event": 
                icon_path = "res://assets/scroll.png"
            "shop":
                icon_path = "res://assets/key.png"
            "rest":
                icon_path = "res://assets/heart.png"
        
        # Check if file exists before loading to prevent debugger spam
        if ResourceLoader.exists(icon_path):
            $Icon.texture = load(icon_path)
        else:
            # Fallback if specific map icons are missing
            $Icon.texture = load("res://assets/skull.png")
    
    # 3. Handle Player Indicator (The "Avatar")
    $PlayerIndicator.visible = is_player_here
    
    # 4. Interaction Highlight
    if is_reachable:
        if $SelectionPulse.has_animation("available"):
            $SelectionPulse.play("available")
    else:
        $SelectionPulse.stop()

func _get_type_icon(type: String) -> String:
	match type:
		"home": return "🏡"
		"town_square": return "🏘️"
		"battle": return "⚔️"
		"shop": return "💰"
		"rest": return "🔥"
		"event": return "❓"
		"boss": return "💀"
		_: return "•"

func _on_button_pressed():
	if node_data:
		node_clicked.emit(node_data)