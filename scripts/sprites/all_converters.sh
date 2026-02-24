#!/bin/bash

# Memory Dungeon - Resource Conversion Master Script
# Runs all 5 specialized converters in sequence.

# List of scripts to execute
SCRIPTS=(
    "card_to_resources.py"
    "item_to_resources.py"
    "npc_to_resources.py"
    "player_to_resources.py"
    "room_to_resources.py"
)

echo "=========================================="
echo "  Memory Dungeon: Resource Generator      "
echo "=========================================="

for script in "${SCRIPTS[@]}"
do
    if [ -f "$script" ]; then
        echo "--> Running: $script..."
        python3 "$script"
        
        if [ $? -eq 0 ]; then
            echo "    [SUCCESS]"
        else
            echo "    [ERROR] $script failed to complete."
            exit 1
        fi
    else
        echo "    [SKIP] $script not found in current directory."
    fi
    echo "------------------------------------------"
done

echo "All tasks completed successfully."  