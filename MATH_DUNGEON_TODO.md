# 🎮 Math Dungeon — Remaining TODO Tasks

> **Project**: Math Dungeon (Godot 4.8)
> **Platform**: Godot (migrated from Unity SRS)
> **Status**: Main Menu ✅ | Dungeon Generation ✅ | FPS Controller ✅ | **Combat, Enemies, Math Doors — NOT STARTED**

---

## Current Project State (What's Done)

| System | Status | Key Files |
|--------|--------|-----------|
| Main Menu (Play, Settings, Quit) | ✅ Done | [maaain-menu.scene.tscn](file:///d:/.PROJECTS/TECHWIZ%20GAME/MATH%20DUNGEON/MATH%20DUNGEON/maaain-menu.scene.tscn), [MainMenu.gd](file:///d:/.PROJECTS/TECHWIZ%20GAME/MATH%20DUNGEON/MATH%20DUNGEON/MainMenu.gd) |
| Settings (Video + Audio tabs) | ✅ Done | [SettingsManager.gd](file:///d:/.PROJECTS/TECHWIZ%20GAME/MATH%20DUNGEON/MATH%20DUNGEON/SettingsManager.gd) |
| FPS Controller (WASD, jump, crouch, sprint, stairs, ladders, water) | ✅ Done | [FPSController.gd](file:///d:/.PROJECTS/TECHWIZ%20GAME/MATH%20DUNGEON/MATH%20DUNGEON/FPSController/FPSController.gd), [FPSController.tscn](file:///d:/.PROJECTS/TECHWIZ%20GAME/MATH%20DUNGEON/MATH%20DUNGEON/FPSController/FPSController.tscn) |
| 3D Dungeon Generation (multi-floor, rooms, hallways, stairs) | ✅ Done | [dungeon.gd](file:///d:/.PROJECTS/TECHWIZ%20GAME/MATH%20DUNGEON/MATH%20DUNGEON/dungeon-generation/dungeon.gd), [dungeon_mesh.gd](file:///d:/.PROJECTS/TECHWIZ%20GAME/MATH%20DUNGEON/MATH%20DUNGEON/dungeon-generation/dungeon_mesh.gd) |
| Dungeon Mesh Builder (cells, doors, walls) | ✅ Done | [dungeon_cell.gd](file:///d:/.PROJECTS/TECHWIZ%20GAME/MATH%20DUNGEON/MATH%20DUNGEON/dungeon-generation/dungeon_cell.gd) |
| Interaction System (ShapeCast + InteractableComponent) | ✅ Done | [InteractableComponent.gd](file:///d:/.PROJECTS/TECHWIZ%20GAME/MATH%20DUNGEON/MATH%20DUNGEON/FPSController/InteractableComponent.gd) |
| Shotgun Model + Recoil (Redemption FPS controller) | ✅ Partial | DungeonTest scene has gun viewmodel, pellet raycasts, recoil script |
| Input Mappings | ✅ Partial | WASD, jump, crouch, sprint, aiming (RMB) exist; **no `shoot`, `interact`, `reload`** actions |

---

## 🔴 TASK 1: Enemy System (HIGH PRIORITY)

### 1A. Enemy Base Script — `Enemy.gd`
- [ ] **Create** `res://enemies/Enemy.gd` (or `res://enemies/base_enemy.gd`)
- [ ] Extend `CharacterBody3D`
- [ ] Properties:
  - `max_health: float = 100.0`
  - `current_health: float = 100.0`
  - `move_speed: float = 3.5`
  - `attack_damage: float = 15.0`
  - `attack_range: float = 2.0` (melee range)
  - `attack_cooldown: float = 1.5` (seconds between attacks)
  - `detection_range: float = 15.0` (how far enemy can see player)
  - `chase_range: float = 20.0`
- [ ] State machine (enum-based):
  - `IDLE` → patrol or stand still
  - `CHASE` → detected player, move towards them
  - `ATTACK` → in melee range, deal damage
  - `HURT` → flash red/knockback when hit
  - `DEAD` → death animation/ragdoll, then `queue_free()`
- [ ] `take_damage(amount: float)` method:
  - Subtract from `current_health`
  - Flash red (modulate tween)
  - If `current_health <= 0` → transition to `DEAD`
  - Emit `signal enemy_died`
- [ ] Navigation via `NavigationAgent3D`:
  - Set target to player position
  - Recalculate path every ~0.5s
  - Use `NavigationRegion3D` baked navmesh in dungeon scene

### 1B. Enemy Scene — `enemy.tscn`
- [ ] **Create** `res://enemies/enemy.tscn`
- [ ] Root: `CharacterBody3D` with `Enemy.gd` attached
- [ ] Children:
  - `CollisionShape3D` (CapsuleShape3D, height ~1.8, radius ~0.4)
  - `NavigationAgent3D` (path_desired_distance = 0.5, target_desired_distance = 1.5)
  - `MeshInstance3D` — placeholder enemy mesh (capsule or a simple humanoid)
  - `AnimationPlayer` — idle, walk, attack, death animations (can be placeholder tween-based)
  - `AttackArea` → `Area3D` with sphere collision (radius = attack_range) to detect player
  - `DetectionArea` → `Area3D` with sphere collision (radius = detection_range)
  - `HitFlashTimer` → `Timer` (one_shot, 0.15s) for damage flash
  - `AttackCooldownTimer` → `Timer` (one_shot, attack_cooldown)

### 1C. Enemy AI Logic
- [ ] `_physics_process(delta)`:
  - State machine switch
  - **IDLE**: Check `DetectionArea` for player → if found, switch to `CHASE`
  - **CHASE**: `NavigationAgent3D.target_position = player.global_position`, move along path. If distance < attack_range → `ATTACK`. If distance > chase_range → back to `IDLE`
  - **ATTACK**: Face player, play attack anim, deal damage to player on `AttackCooldownTimer` timeout. If player moves out of range → `CHASE`
  - **HURT**: Brief pause (0.15s), then resume previous state
  - **DEAD**: Play death, disable collision, `queue_free()` after 2s
- [ ] Enemy must be on collision layer 4 (enemies), scan for player on layer 2

### 1D. Enemy Spawning
- [ ] **Create** `res://enemies/EnemySpawner.gd`
- [ ] Attach to dungeon generation: after dungeon builds, spawn N enemies per room
- [ ] `spawn_enemies_in_rooms(room_tiles: Array)` — pick random floor tiles within each room, instance enemy, add to scene tree
- [ ] Configurable: `enemies_per_room: int = 2`, `enemy_scene: PackedScene`

---

## 🔴 TASK 2: Player Health System (HIGH PRIORITY)

### 2A. Player Health Script — `PlayerHealth.gd`
- [ ] **Create** `res://Player_Controller/scripts/PlayerHealth.gd`
- [ ] Properties:
  - `max_health: float = 100.0`
  - `current_health: float = 100.0`
  - `is_dead: bool = false`
- [ ] Signals:
  - `signal health_changed(new_health: float, max_health: float)`
  - `signal player_died`
- [ ] `take_damage(amount: float)`:
  - If `is_dead`: return
  - `current_health = max(0, current_health - amount)`
  - Emit `health_changed`
  - Screen flash red (damage vignette)
  - If `current_health <= 0` → `die()`
- [ ] `heal(amount: float)`:
  - `current_health = min(max_health, current_health + amount)`
  - Emit `health_changed`
- [ ] `die()`:
  - `is_dead = true`
  - Emit `player_died`
  - Show Game Over UI
  - Disable player input
  - Option: "Restart" → reload scene, "Main Menu" → go to main menu

### 2B. Integrate with FPSController
- [ ] Add `PlayerHealth` as child node of `CharacterBody3D` in [FPSController.tscn](file:///d:/.PROJECTS/TECHWIZ%20GAME/MATH%20DUNGEON/MATH%20DUNGEON/FPSController/FPSController.tscn)
- [ ] Or attach directly in the dungeon test scene
- [ ] Enemy `ATTACK` state calls `player.get_node("PlayerHealth").take_damage(attack_damage)`
- [ ] Player must be findable by enemies (group `"player"`, or global reference)

---

## 🔴 TASK 3: Shotgun / Weapon System (HIGH PRIORITY)

### 3A. Shotgun Mechanics — `Shotgun.gd`
- [ ] **Create** `res://weapons/Shotgun.gd`
- [ ] Properties:
  - `damage_per_pellet: float = 15.0`
  - `pellet_count: int = 8`
  - `spread_angle: float = 5.0` (degrees)
  - `max_range: float = 30.0`
  - `fire_rate: float = 0.8` (seconds between shots)
  - `ammo_current: int = 6`
  - `ammo_max: int = 6`
  - `reload_time: float = 2.5`
  - `is_reloading: bool = false`
- [ ] Signals:
  - `signal ammo_changed(current: int, max: int)`
  - `signal weapon_fired`
  - `signal reload_started`
  - `signal reload_finished`
- [ ] `shoot()`:
  - If `is_reloading` or `ammo_current <= 0`: return
  - For each pellet (0..pellet_count):
    - Cast a `RayCast3D` from camera forward with random spread
    - If hits something on enemy collision layer → call `enemy.take_damage(damage_per_pellet)`
    - Spawn hit decal / particle effect at impact point
  - `ammo_current -= 1`; emit `ammo_changed`
  - Camera shake / recoil
  - Muzzle flash
  - Shotgun sound effect (SFX bus)
- [ ] `reload()`:
  - `is_reloading = true`
  - Start reload timer
  - On timeout: `ammo_current = ammo_max`, `is_reloading = false`, emit `reload_finished`

### 3B. Input Actions (Add to project.godot)
- [ ] **Add** `shoot` action → Left Mouse Button (LMB)
- [ ] **Add** `reload` action → R key
- [ ] **Add** `interact` action → E key (for doors / MCQ interaction)

### 3C. Wire into FPS Controller
- [ ] In `_unhandled_input` or `_process` of FPSController:
  - `if Input.is_action_just_pressed("shoot"): $Shotgun.shoot()`
  - `if Input.is_action_just_pressed("reload"): $Shotgun.reload()`
- [ ] The existing `PelletRaycast` and `gun-recoil.gd` in the DungeonTest scene may be reusable — investigate [player-2.gd](file:///d:/.PROJECTS/TECHWIZ%20GAME/MATH%20DUNGEON/MATH%20DUNGEON/FPSController/redemptionfpscontroller/scripts/player-2.gd) and [WeaponViewmodelController.gd](file:///d:/.PROJECTS/TECHWIZ%20GAME/MATH%20DUNGEON/MATH%20DUNGEON/FPSController/redemptionfpscontroller/scripts/WeaponViewmodelController.gd) for existing gun logic

### 3D. Visual Feedback
- [ ] Muzzle flash (OmniLight3D + GPUParticles3D, brief 0.05s)
- [ ] Hit sparks at impact point
- [ ] Enemy flinch/knockback on hit
- [ ] Screen shake on fire (use existing [CameraShaker.gd](file:///d:/.PROJECTS/TECHWIZ%20GAME/MATH%20DUNGEON/MATH%20DUNGEON/FPSController/redemptionfpscontroller/scripts/CameraShaker.gd))

---

## 🔴 TASK 4: Math MCQ Door System (HIGH PRIORITY — Core Game Mechanic!)

> **This is the defining feature of "Math Dungeon"** — doors between dungeon rooms are locked and require solving a math MCQ to unlock.

### 4A. Math Question Database — `MathQuestionDB.gd`
- [ ] **Create** `res://math_system/MathQuestionDB.gd` (autoload singleton)
- [ ] Question structure:
  ```gdscript
  class MathQuestion:
      var question_text: String    # e.g. "What is 7 × 8?"
      var options: Array[String]   # ["54", "56", "64", "48"]
      var correct_index: int       # 1 (index of "56")
      var difficulty: int          # 1=easy, 2=medium, 3=hard
  ```
- [ ] Question categories:
  - **Easy** (Difficulty 1): Basic addition/subtraction (e.g., "12 + 15 = ?")
  - **Medium** (Difficulty 2): Multiplication/division (e.g., "144 ÷ 12 = ?")
  - **Hard** (Difficulty 3): Order of operations, square roots, fractions (e.g., "√144 + 3² = ?")
- [ ] `get_random_question(difficulty: int) -> MathQuestion`:
  - **Procedural generation**: randomly generate arithmetic problems on-the-fly
  - Addition: `a + b` where a,b ∈ [1..99]
  - Subtraction: `a - b` (ensure positive result)
  - Multiplication: `a × b` where a,b ∈ [2..12]
  - Division: generate `a × b`, question = `(a×b) ÷ b = ?`
  - Generate 3 wrong answers (close to correct, but not equal)
  - Shuffle options randomly

### 4B. Math MCQ UI — `MathDoorUI.tscn` + `MathDoorUI.gd`
- [ ] **Create** `res://math_system/MathDoorUI.tscn`
- [ ] UI Layout (CanvasLayer, centered panel):
  - Semi-transparent dark overlay (full screen)
  - Centered Panel (600×400):
    - Title Label: "🔒 LOCKED DOOR — Solve to Enter"
    - Question Label: "What is 7 × 8?"
    - 4 Option Buttons (A/B/C/D) in a 2×2 grid or vertical list
    - Timer bar (optional: 15 seconds to answer)
    - "Skip" button (uses a skip token if available)
  - Feedback:
    - ✅ Correct → green flash, door opens, UI closes
    - ❌ Wrong → red flash, try again (or penalty: lose health / question changes)
- [ ] **Create** `res://math_system/MathDoorUI.gd`
- [ ] `show_question(question: MathQuestion, door_ref: Node)`:
  - Populate UI with question text and options
  - Pause game (`get_tree().paused = true`) or release mouse
  - `Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)`
- [ ] On option button pressed:
  - Check if selected index == `question.correct_index`
  - If correct: emit `signal door_unlocked(door_ref)`, hide UI, resume game
  - If wrong: shake panel, flash red, optionally deduct health, generate new question or allow retry

### 4C. Door Script — `MathDoor.gd`
- [ ] **Create** `res://math_system/MathDoor.gd`
- [ ] Extends `StaticBody3D` (or `AnimatableBody3D`)
- [ ] Properties:
  - `is_locked: bool = true`
  - `difficulty: int = 1`
  - `door_mesh: MeshInstance3D` (visual)
  - `collision: CollisionShape3D` (blocks passage)
- [ ] Has `InteractableComponent` child → when player interacts (E key):
  - If `is_locked`: show `MathDoorUI` with a random question
  - If unlocked: do nothing (door already open)
- [ ] `unlock()`:
  - `is_locked = false`
  - Play open animation (rotate door, or slide up, or fade out)
  - Disable collision (let player pass)
  - Optional: change door mesh appearance (unlocked color)

### 4D. Door Placement in Dungeon
- [ ] Modify [dungeon_mesh.gd](file:///d:/.PROJECTS/TECHWIZ%20GAME/MATH%20DUNGEON/MATH%20DUNGEON/dungeon-generation/dungeon_mesh.gd):
  - When GridMap cell type = `2` (Door Tile), instantiate a `MathDoor` at that position
  - Orient door to face the correct direction (perpendicular to hallway)
  - Assign difficulty based on dungeon depth/floor level
- [ ] Alternatively: doors spawn at room-to-hallway transitions (perimeter tiles marked as type 2)

### 4E. Register as Autoload
- [ ] Add `MathQuestionDB` to `project.godot` autoload section

---

## 🟡 TASK 5: HUD / In-Game UI (MEDIUM PRIORITY)

### 5A. HUD Scene — `HUD.tscn` + `HUD.gd`
- [ ] **Create** `res://ui/HUD.tscn`
- [ ] Layout (CanvasLayer):
  - **Health Bar** (top-left):
    - Red progress bar or segmented hearts
    - Label: "HP: 100/100"
  - **Ammo Counter** (bottom-right):
    - Shotgun icon + "6/6"
    - Shows reload indicator when reloading
  - **Crosshair** (center):
    - Simple cross or dot reticle
    - Changes color when aiming at enemy (red) vs nothing (white)
  - **Interaction Prompt** (bottom-center):
    - "Press [E] to interact" — shows when looking at door/interactable
  - **Damage Vignette** (full screen overlay):
    - Flashes red when taking damage, fades out
  - **Kill Counter / Score** (optional, top-right):
    - "Enemies: 0/12"

### 5B. Game Over Screen
- [ ] **Create** `res://ui/GameOver.tscn`
- [ ] "YOU DIED" title
- [ ] Stats: enemies killed, doors unlocked, time survived
- [ ] Buttons: "Restart" (reload scene), "Main Menu" (go to MainMenu)

### 5C. Pause Menu
- [ ] **Create** `res://ui/PauseMenu.tscn`
- [ ] ESC to toggle
- [ ] "Resume", "Settings", "Main Menu" buttons
- [ ] `get_tree().paused = true/false`
- [ ] Set process_mode = ALWAYS on pause menu node

---

## 🟡 TASK 6: Navigation Mesh (MEDIUM PRIORITY)

### 6A. NavigationRegion3D for Dungeon
- [ ] After dungeon generation completes, bake a `NavigationRegion3D`
- [ ] Add `NavigationRegion3D` as child of dungeon scene root
- [ ] Configure `NavigationMesh`:
  - `agent_radius = 0.4`
  - `agent_height = 1.8`
  - `cell_size = 0.25`
- [ ] Call `navigation_region.bake_navigation_mesh()` after mesh build completes
- [ ] This is **required** for enemy `NavigationAgent3D` pathfinding

---

## 🟢 TASK 7: Audio & Polish (LOW PRIORITY)

### 7A. Sound Effects
- [ ] Shotgun fire SFX
- [ ] Shotgun reload SFX
- [ ] Enemy hurt sound
- [ ] Enemy death sound
- [ ] Enemy attack/growl sound
- [ ] Door unlock sound
- [ ] MCQ correct answer chime
- [ ] MCQ wrong answer buzz
- [ ] Player damage grunt
- [ ] Ambient dungeon background (eerie music/drips)
- [ ] All sounds → SFX or Music audio bus

### 7B. Visual Polish
- [ ] Enemy death particles
- [ ] Door unlock particle effect
- [ ] Torch/light sources in dungeon rooms
- [ ] Fog/atmosphere for depth

---

## 🟢 TASK 8: Game Flow & Progression (LOW PRIORITY)

### 8A. Level Progression
- [ ] Track number of doors unlocked
- [ ] Track number of enemies killed
- [ ] After all doors on a floor are unlocked → reveal stair to next floor
- [ ] After clearing final floor → "You Win" screen

### 8B. Difficulty Scaling
- [ ] Floor 1: Easy math questions, 1-2 enemies per room
- [ ] Floor 2: Medium math questions, 2-3 enemies per room
- [ ] Floor 3: Hard math questions, 3-4 enemies per room
- [ ] Enemy stats scale with floor (more health, more damage)

### 8C. Score System
- [ ] Points for correct MCQ answers
- [ ] Points for enemy kills
- [ ] Time bonus
- [ ] Leaderboard (local save with ConfigFile)

---

## File Structure (Proposed New Files)

```
res://
├── enemies/
│   ├── Enemy.gd              ← TASK 1A
│   ├── enemy.tscn            ← TASK 1B
│   └── EnemySpawner.gd       ← TASK 1D
├── weapons/
│   └── Shotgun.gd            ← TASK 3A
├── math_system/
│   ├── MathQuestionDB.gd     ← TASK 4A (autoload)
│   ├── MathDoorUI.tscn       ← TASK 4B
│   ├── MathDoorUI.gd         ← TASK 4B
│   ├── MathDoor.gd           ← TASK 4C
│   └── MathDoor.tscn         ← TASK 4C
├── ui/
│   ├── HUD.tscn              ← TASK 5A
│   ├── HUD.gd                ← TASK 5A
│   ├── GameOver.tscn          ← TASK 5B
│   └── PauseMenu.tscn        ← TASK 5C
└── Player_Controller/
    └── scripts/
        └── PlayerHealth.gd   ← TASK 2A
```

---

## Implementation Order (Recommended)

| Order | Task | Reason |
|-------|------|--------|
| 1️⃣ | **Task 3B** — Input Actions | Everything else depends on `shoot`, `interact`, `reload` inputs |
| 2️⃣ | **Task 2** — Player Health | Enemies need a target to damage |
| 3️⃣ | **Task 5A** — HUD | Need to see health/ammo before combat testing |
| 4️⃣ | **Task 3** — Shotgun | Player needs to fight |
| 5️⃣ | **Task 6** — NavMesh | Enemies need pathfinding |
| 6️⃣ | **Task 1** — Enemies | Now enemies can navigate, attack, and be killed |
| 7️⃣ | **Task 4** — Math MCQ Doors | Core mechanic, depends on interaction system |
| 8️⃣ | **Task 5B/C** — Game Over / Pause | Polish game flow |
| 9️⃣ | **Task 7** — Audio & Polish | Final pass |
| 🔟 | **Task 8** — Progression & Scoring | Endgame loop |

---

> [!IMPORTANT]
> The **Math MCQ Door system (Task 4)** is the core unique mechanic that defines "Math Dungeon." It should be fully functional and polished even if other features are simplified.

> [!NOTE]
> The existing [DungeonTest.tscn](file:///d:/.PROJECTS/TECHWIZ%20GAME/MATH%20DUNGEON/MATH%20DUNGEON/DungeonTest.tscn) already has a shotgun viewmodel with pellet raycasts, recoil, camera effects, and a player-2.gd script from the Redemption FPS controller. **Investigate these files first** before building from scratch — they may already handle shooting mechanics.

> [!WARNING]
> The dungeon GridMap cell type `2` (Door Tile) is already generated by `dungeon.gd` at room-hallway transitions. The Math Door system should **hook into this existing system** rather than creating a separate door placement mechanism.
