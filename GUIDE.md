# Math Dungeon — Briefing Guide for Zainab

> Use this to write the **User Guide**, **Developer Guide**, and **Presentation**.

---

## 1. What Is Math Dungeon?

A **first-person 3D dungeon crawler** where doors between rooms are locked behind **math MCQ questions**. The player explores a procedurally generated multi-floor dungeon, fights enemies with a shotgun, and solves math problems to progress.

**Genre**: FPS + Educational Puzzle
**Engine**: Godot 4.8 (GDScript only, no C#)
**Platform**: PC (Windows)
**Team Project**: TechWiz Game Foundry

---

## 2. Core Gameplay Loop

```
Main Menu → Enter Dungeon → Explore Rooms → Encounter Locked Door
    → Solve Math MCQ → Door Opens → Fight Enemies → Clear Floor
    → Descend Stairs → Harder Questions + Tougher Enemies → Win/Die
```

1. Player spawns in a procedurally generated dungeon
2. Rooms are connected by hallways with **locked doors**
3. To unlock a door → a math MCQ popup appears (4 choices, 1 correct)
4. Correct answer = door opens | Wrong answer = health penalty or retry
5. Enemies roam rooms — player uses shotgun to fight
6. Clear all floors to win

---

## 3. Controls (User Guide)

| Action | Key |
|--------|-----|
| Move | W/A/S/D |
| Look | Mouse |
| Jump | Space |
| Sprint | Left Shift |
| Crouch | C |
| Shoot | Left Mouse Button |
| Aim (ADS) | Right Mouse Button |
| Reload | R |
| Interact (doors) | E |
| Pause | Escape |

---

## 4. Features Summary

| Feature | Description |
|---------|-------------|
| **Procedural Dungeon** | Multi-floor 3D dungeon generated from rooms, hallways, doors, and stairs using Delaunay triangulation + MST + A* pathfinding |
| **Math MCQ Doors** | Locked doors require solving a randomly generated math question (addition, subtraction, multiplication, division) |
| **Difficulty Scaling** | Floor 1 = easy math, Floor 2 = medium, Floor 3 = hard; enemy count and stats also scale |
| **FPS Combat** | Shotgun with pellet spread, ammo, reload, muzzle flash, recoil |
| **Enemies** | AI enemies with idle/chase/attack states, NavigationAgent3D pathfinding, deal melee damage |
| **Player Health** | HP bar, damage vignette, death → Game Over screen |
| **Settings** | Fullscreen, resolution, V-Sync, quality, master/music/SFX volume, mute |
| **Main Menu** | Play, Settings, Quit — custom fonts, dark theme |

---

## 5. Tech Architecture (Developer Guide)

### Engine & Language
- **Godot 4.8** (open-source game engine)
- **GDScript** — Python-like scripting language native to Godot
- No external dependencies or frameworks

### Project Structure

```
res://
├── maaain-menu.scene.tscn   ← Main Menu (start scene)
├── MainMenu.gd               ← Menu logic (play/settings/quit)
├── SettingsManager.gd         ← Persistent video/audio settings
├── project.godot              ← Engine config, input mappings, autoloads
│
├── FPSController/
│   ├── FPSController.tscn     ← Player character (CharacterBody3D)
│   ├── FPSController.gd       ← Movement: WASD, jump, crouch, sprint, stairs, ladders
│   ├── InteractableComponent.gd ← Reusable interaction system
│   └── redemptionfpscontroller/ ← Shotgun viewmodel, camera effects, pellet raycasts
│
├── dungeon-generation/
│   ├── dungeon.gd             ← Room placement, Delaunay, MST, hallway carving
│   ├── dungeon_mesh.gd        ← GridMap → 3D mesh cells with walls/doors
│   ├── dungeon_cell.gd        ← Individual cell wall/door removal
│   ├── delaunay_3d.gd         ← 3D Bowyer-Watson tetrahedralization
│   └── dungeon_pathfinder_3d.gd ← Custom A* with stair jumps
│
├── enemies/                   ← Enemy AI, health, navigation
├── math_system/               ← MCQ generator, door UI, locked doors
├── weapons/                   ← Shotgun mechanics
├── ui/                        ← HUD, GameOver, PauseMenu
└── DungeonTest.tscn           ← Main gameplay scene
```

### Key Design Patterns
- **Signals**: Event system — `health_changed`, `door_unlocked`, `enemy_died`
- **Scene Composition**: Each system is a reusable `.tscn` scene
- **Autoloads**: Global singletons (MathQuestionDB, GlobalVariables)
- **@tool scripts**: Dungeon generation runs in-editor for previewing
- **NavigationAgent3D**: Built-in Godot nav for enemy AI pathfinding

### Dungeon Generation Algorithm
1. Place N rooms randomly across multiple floors
2. Connect rooms using Delaunay triangulation (3D)
3. Build MST to guarantee all rooms are reachable
4. Add extra edges (25%) for interesting loops
5. A* pathfind each edge → carve hallways, place doors, carve stairs
6. Build 3D meshes from GridMap data

---

## 6. Presentation Talking Points

### Slide 1 — Title
- "Math Dungeon" — An Educational FPS Dungeon Crawler
- Team: TechWiz Game Foundry

### Slide 2 — Problem Statement
- Math practice is boring → gamify it
- Combine FPS action with math problem-solving
- Target: students who want to learn math engagingly

### Slide 3 — Solution
- Procedurally generated 3D dungeon = infinite replayability
- Locked doors require math MCQs = forced learning
- Difficulty scales per floor = progressive challenge
- FPS combat = engagement and motivation

### Slide 4 — Tech Stack
- Godot 4.8 (free, open-source)
- GDScript (built-in scripting)
- No external services or APIs
- Runs offline on Windows PC

### Slide 5 — Key Features
- Procedural dungeon generation (rooms, hallways, stairs, multiple floors)
- Math MCQ door system (4-choice, procedurally generated)
- FPS combat (shotgun, enemies with AI)
- Full settings system (video, audio)
- Main menu with custom UI

### Slide 6 — Architecture
- Scene-based composition
- Signal-driven communication
- GridMap → 3D mesh pipeline
- NavigationAgent3D for enemy AI

### Slide 7 — Demo
- Main menu → start game → explore dungeon → locked door → solve MCQ → fight enemy

### Slide 8 — Challenges & Lessons
- Migrated from Unity to Godot mid-project
- Procedural 3D dungeon gen with stairs was complex
- Balancing math difficulty with game flow

### Slide 9 — Future Work
- More question types (algebra, geometry)
- Multiplayer co-op
- Mobile port
- Leaderboards and achievements
- More enemy types and boss fights

---

## 7. Quick Reference for User Guide

### How to Play
1. Launch the game → Main Menu appears
2. Click **PLAY GAME** to enter the dungeon
3. Move with WASD, look with mouse
4. Find a locked door → walk up to it and press **E**
5. A math question appears — click the correct answer
6. Correct = door opens! Wrong = try again (health penalty)
7. Watch out for enemies — shoot them with Left Click
8. Press R to reload your shotgun
9. Explore all rooms, solve all doors, survive all enemies
10. Reach the final floor to win

### Settings
- **Video Tab**: Fullscreen, Resolution, V-Sync, Quality
- **Audio Tab**: Master/Music/SFX volume sliders, Mute toggle

### Tips
- Listen for enemy sounds — they growl when they spot you
- Conserve ammo — aim carefully with right-click
- Harder math on deeper floors — brush up on multiplication tables!
