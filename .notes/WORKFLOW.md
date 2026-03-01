
# Code development 

* Generate AI context files 

```
python3 ./.notes/ai_context_generator.py
python3 ./.notes/ai_project_summary.py
```

* Update todo list 

```
Update todo list based on project context  
{
    ./.notes/ai_context_generator.py
    ./.notes/ai_project_summary.py
    .ai-todo.md
} 
```

* Feature 

``` 
implement next feature on todo list 
request additional files as rqd 
```


* YOLO ..

```
implement feature 
compare / update existing file   
run test cases 
```



"Read .ai-context.md for our Godot architecture. Based on the mapping in .notes/SUMMARY.md, create a new feature 
{in /features/combat that inherits from BaseCombatEntity.}"



# Engine - Menu  

# Engine - Map 

# Engine - Combat 

# Engine - Dialog

# Engine - Events  

# Engine - Character Screen

# Engine - Bosses / Level


# Resources - NPCs

Data driven resource files from Google sheets (*.csv export) to *.tres files  

## Update data  

Google Drive > Memoria > NPC 
https://docs.google.com/spreadsheets/d/1MgpBBFfe3s4lEDskU4rbwJQ8lc8gmr7o0pebAP7BaZI/edit?gid=0#gid=0

## Export CSV 

File Export     NPC.csv 
Copy            ./.notes/NPC/NPC.csv

## Run translator 

```
python ./.notes/NPC/csv_to_resources.py
```


# Story - E2E 

# Story - Characters 


# Assets - Menus  
# Assets - UI Large  

# Assets - Card Icon 

# Assets - Map Scene 
# Assets - Map World
# Assets - Map Icon 

# Assets - Music 
# Assets - SFX

# Assets - Video 

# Assets - Character  
# Assets - NPC / Enemy  

Image to sprite map (png), using reference image and comfyUI to generate 8x1 image maps for idle, attack, defend 

## Run ComfyUI 

Win powershell
```
cd C:\ComfyUI_windows_portable\
.\run_nvidia_gpu.bat
```
http://127.0.0.1:8188/

## Run Python workflow 

Win powershell
```
cd C:\Users\pkubi\production\memoria\image\spritemap
python .\sprite_workflow_api.py
```

## Inspect output 

Move 
From    C:\ComfyUI_windows_portable\Comfy\output
To      C:\Users\pkubi\production\memoria\images\spritemap


## Post processing 

```
cd C:\Users\pkubi\production\memoria\images\spritemap
python .\sprite_processing.py --execute
```