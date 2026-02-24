@echo off
TITLE Memory Dungeon Resource Master
echo ==========================================
echo   Memory Dungeon: Resource Generator      
echo ==========================================

:: Run Card Converter
if exist card_to_resources.py (
    echo --^> Running: card_to_resources.py
    python card_to_resources.py
    if %errorlevel% neq 0 goto :error
)

:: Run Item Converter
if exist item_to_resources.py (
    echo --^> Running: item_to_resources.py
    python item_to_resources.py
    if %errorlevel% neq 0 goto :error
)

:: Run NPC Converter
if exist npc_to_resources.py (
    echo --^> Running: npc_to_resources.py
    python npc_to_resources.py
    if %errorlevel% neq 0 goto :error
)

:: Run Player Converter
if exist player_to_resources.py (
    echo --^> Running: player_to_resources.py
    python player_to_resources.py
    if %errorlevel% neq 0 goto :error
)

:: Run Room Converter
if exist room_to_resources.py (
    echo --^> Running: room_to_resources.py
    python room_to_resources.py
    if %errorlevel% neq 0 goto :error
)

echo ==========================================
echo   SUCCESS: All resources generated.
echo ==========================================
pause
exit /b 0

:error
echo ==========================================
echo   CRITICAL ERROR: Script execution failed.
echo ==========================================
pause
exit /b 1