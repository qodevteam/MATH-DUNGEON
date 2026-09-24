# 3D Dungeon + Stairs — Analysis & Plan

> **STATUS: ANALYSIS ONLY — NO SCRIPTING YET.**
> Open questions must be answered before any code is written (see bottom).
> Last updated: 2026-09-25

---

## 1. Sources

| Source | URL |
|---|---|
| Video (transcript, 3D part starts ~4:17) | https://youtu.be/h64U6j_sFgs |
| Blog post (full written version) | https://vazgriz.com/119/procedurally-generated-dungeons/ |
| Reference repo | https://github.com/vazgriz/DungeonGenerator |
| Key ref files | `Assets/Scripts3D/Delaunay3D.cs`, `DungeonPathfinder3D.cs`, `Generator3D.cs`, `Grid3D.cs` |
| Delaunay3D origin (MIT) | https://github.com/Bl4ckb0ne/delaunay-triangulation |

Language note: project runs **Godot 4.8 dev6 mono** → `.cs` scripts are allowed. The two hard pieces
(`Delaunay3D`, `DungeonPathfinder3D`) are near-verbatim C#-to-C# ports if we choose C#.

---

## 2. Current project state (verified from scenes/files)

### Grid & scales
| Item | Value | Status |
|---|---|---|
| GridMap `cell_size` | `(128, 128, 128)` | ✅ |
| `cell_center_y` | `false` → cell y spans `[y*128, y*128+128]`, floor plane at `y*128` | ✅ |
| `cell_center_x/z` | default `true` → cell c spans `[c*128-64, c*128+64]` | ✅ |
| `dungeon_cell.tscn` root scale | `4` (art base 32 → 128) | ✅ |
| Cell interior height | ceiling local `26.555 × 4 = 106.22` (gap 106.22→128 = sealed slab) | ✅ |
| `dungeon_mesh.gd` position | `Vector3(cell) * grid_map.cell_size.x` | ✅ |

### `dungeon_stair.tscn` (final, user-confirmed)
| Item | Value |
|---|---|
| Root scale | `4` |
| Stairs rotation | `X = -90°` (mesh rise → world **+Y**, ascending from origin) |
| Stairs scale | `(30.92, 15.06, 13.98)` |
| World result | **run = 256** along world **X**, **width = 128** along world **Z**, **rise = 128** |
| Origin | bottom-center of run (ramp low end at y=0) |
| Implication | stair travel axis in the scene = **world X**; generator must **yaw ±90°** for Z-travel stairs |

### GridMap items (`DungeonTiles.tres` + `dungeon_tiles.tscn`)
| Index | Name | Status |
|---|---|---|
| 0 | Room Tile (blue) | ✅ |
| 1 | Hallway Tile (cyan) | ✅ |
| 2 | Door Tile (yellow) | ✅ |
| 3 | Border Tile (red) | ✅ |
| 4 | Stair Tile (green) | ✅ exists both files |

### Current algorithm (`dungeon.gd`, 201 lines) — **2D only**
- Rooms placed at `y = 0` only (`make_room`, line 122–151)
- Delaunay: `Geometry2D.triangulate_delaunay` on `Vector2(x,z)` (line 76)
- MST: custom Prim over `AStar2D` (line 82–108)
- Extra edges: `survival_chance` (line 112–117)
- Hallways: `AStarGrid2D`, rooms marked **solid**, **no cost function** (line 184–201)
- Border: `visualize_border()` fills only `y = 0` ring

### Current mesh builder (`dungeon_mesh.gd`)
- Handle matrix for **4 horizontal directions only** (up/down/left/right = ±Z/±X)
- No ±Y neighbor logic → no floor/ceiling openings possible
- Exports `hide_grid_map_after_build`, `remove_cell_collision` exist but **never wired into `create_dungeon()`**

### Known bugs / debt
1. **Save persistence**: `dungeon_cell.gd` uses `queue_free()`; deletions on packed-scene instances likely not persisted → game load shows all doors (root-cause hypothesis, unfixed).
2. **Stale scene**: `dungeon_level_generation.tscn` DunMesh children have `Transform3D(8,…)` at **256 spacing** (generated when cell_size was 256) — must regenerate.
3. `hide_grid_map_after_build` / `remove_cell_collision` unused.

---

## 3. vazgriz algorithm reference (from transcript + source)

### 2D baseline (steps 1–5) — what we already mirror
1. Place rooms (random, non-overlapping, 1-unit XZ buffer)
2. Delaunay triangulation (Bowyer-Watson)
3. MST via Prim (guarantees connectivity)
4. Randomly add 12.5% of remaining triangulation edges (loops)
5. A* per hallway edge with cost function:
   - existing hallway = cheap, carve new = +1, room = +5 (allowed but expensive)
   - world mutates after each path so later paths reuse/avoid

### 3D extension
1. **Rooms in 3D** — random y too; rooms may span multiple floors (`roomMaxSize.y > 1`).
2. **Delaunay tetrahedralization** — Bowyer-Watson with **circumspheres** instead of circumcircles
   (4×4 determinants; `Delaunay3D.cs`). Produces tetrahedra → edges that cross floors.
3. **Prim + random edges** — trivial (same code on 3D edge list).
4. **Custom 3D pathfinder** — the hard part (`DungeonPathfinder3D.cs`):

#### Exact mechanics (from source)
```
Neighbor offsets:
  flat:  (±1,0,0), (0,0,±1)
  stair: (±3,+1,0), (0,+1,±3)   ← jump = 3 horizontal + 1 vertical   (also −1 vertical)
```
- Each `Node` keeps `PreviousSet: HashSet<position>` = ALL positions in its current path.
  A neighbor is **rejected if it is in `node.PreviousSet`** (prevents one search's path from
  cutting through a staircase it just created).
- **Stair safety**: when evaluating a stair move from `a` with horizontal `h` and vertical `v`:
  - reject if `PreviousSet` contains any of `a+h`, `a+2h`, `a+v+h`, `a+v+2h`
  - on accept, add those 4 cells to neighbor's `PreviousSet`
- **Cost function** (`Generator3D.cs`):
  - flat move: heuristic = distance to end; `Hallway +0`, `None +1` (carve), `Room +5`,
    existing `Stairs` = traversable with heuristic only (**reusing stairs is free**)
  - stair move: endpoints `a`,`b` must be `None|Hallway`; all 4 stair cells must be `None`;
    cost = `100 + heuristic`; sets `isStairs`
- **Carving** (on successful path):
  - `None` cells along path → `Hallway`
  - for each vertical step `delta.y != 0` from `prev`: the 4 cells
    `prev+h`, `prev+2h`, `prev+v+h`, `prev+v+2h` → `Stairs` (2 cells at lower floor + 2 at upper)
  - entry = `prev` (plain hallway), exit = `prev + (3,v,0)` (plain hallway)
- **Failed paths**: `path == null` → edge skipped (leftover lines in video). Expected, not an error.
- Runs **once at level start**; O(N²)-ish path-history cost is acceptable.

#### Stair footprint (grid cells) — for our 128-unit cells
```
lower floor y:     [entry] [stair] [stair] [exit(y+1)]
cells:              P       P+h     P+2h    P+3h      ← horizontal run
upper floor y+1:            (same x cells, y+1) are the top-row stair cells
stair block = 2×2: (P+h, y), (P+2h, y), (P+h, y+1), (P+2h, y+1)
```
- Mesh: ONE stair instance spanning run 256 × rise 128, world position = center of the 2-cell run,
  bottom at `y*128`; yaw 0° if travel = X, 90° if travel = Z.
- Vertical openings in art (our cell has floor plane + ceiling at 106.22):
  - bottom-row stair cells → **remove ceiling** (ramp + headroom passes through)
  - top-row stair cells → **remove floor** (character's body/head occupies, lands on ramp)
  - entry/exit cells: normal hallway (floor/ceiling intact)

### Emergent behaviors to expect (video)
- two stairs side by side; two stairs into same door; 2-floor descent with landing between;
  hallways merging into large areas; some edges fail to path.

---

## 4. Gap analysis — what's missing vs current algorithm

| # | vazgriz piece | Current state | Gap |
|---|---|---|---|
| 1 | Rooms on multiple floors (3D) | `make_room()` hardcodes `y = 0` | **Missing** — need `floor_count` + random y (+ optional multi-floor room height) |
| 2 | Delaunay tetrahedralization (circumspheres) | `Geometry2D.triangulate_delaunay` (2D) | **Missing** — no 3D equivalent in Godot; must port `Delaunay3D.cs` |
| 3 | MST on 3D edges | Prim over `AStar2D`/`Vector2` | **Missing (trivial)** — switch to 3D points |
| 4 | Random extra edges (12.5%) | `survival_chance` ✅ | ✅ have (works on any edge list) |
| 5 | Custom 3D pathfinder (stair jumps, PreviousSet, cost fn) | `AStarGrid2D`, no costs, rooms solid | **Missing entirely** — biggest piece |
| 6 | Stair cell carving (2×2 block, item 4) | nothing | **Missing** |
| 7 | Failed-path tolerance | n/a (A* always returns) | **Missing** — must skip edges gracefully |
| 8 | Mesh: vertical openings for stairs | handle matrix = 4 horizontal only | **Missing** — ±Y neighbor logic |
| 9 | Mesh: stair instance placement + yaw | nothing | **Missing** |
| 10 | Border walls across all floors | `visualize_border()` y=0 only | **Missing** |
| 11 | Grid Y extent for N floors | GridMap used as flat plane | **Missing** — `floor_count` drives Y size |
| 12 | Cost function (hallway reuse, carve, room) | none (rooms solid) | **Missing** (design choice: see Q4) |

---

## 5. Proposed implementation (NOT STARTED)

### Option A — C# ports (recommended if user agrees)
| New file | Port of | Notes |
|---|---|---|
| `delaunay_3d.cs` | `Delaunay3D.cs` | replace Unity `Vector3/Matrix4x4/Mathf` with `Godot.Vector3` + manual 4×4 determinants or `System.Numerics` |
| `dungeon_pathfinder_3d.cs` | `DungeonPathfinder3D.cs` + `Grid3D.cs` | incl. cost function from `Generator3D.cs`; priority queue = sorted set / linear min (N small) |
| `dungeon.gd` (rewrite) | `Generator3D.cs` flow | orchestration stays in GDScript OR new `generator_3d.cs` |

### Option B — all GDScript
Same pieces, hand-ported; slower to write, no Unity→Godot API friction.

### Existing files to edit (either option)
- `dungeon.gd`: floor_count, 3D rooms, 3D MST, pathfind step, stair carving, border per floor
- `dungeon_mesh.gd`: handle item 4 (stair instance + yaw), ±Y neighbors
  (remove ceiling of bottom stair row / floor of top stair row), wire
  `hide_grid_map_after_build`
- `dungeon_cell.gd`: `queue_free()` → `free()` (persistence fix) — *if staying with editor bake*
- Scene edits (user): set `floor_count`, add stair handling to DunMesh exports, regenerate

### Decision needed: generation timing
- **Editor bake** (current `@tool` + Start toggle): scene grows huge, persistence bug bites,
  every param change = re-save.
- **Runtime `_ready()`** (recommended earlier): GridMap = source of truth, scene file stays small,
  fixes persistence bug by design; editor shows GridMap debug tiles only (or a "preview" bake).

---

## 6. Open questions — ANSWER BEFORE SCRIPTING

1. **Language**: C# ports (A) or GDScript (B)? *(mono is available; A is near-verbatim)*
2. **Generation timing**: editor-bake `@tool` (fix persistence) or runtime `_ready()` (recommended)?
3. **Rooms**: single-floor rooms only, or allow tall rooms spanning floors (vazgriz `size.y > 1`)?
4. **Room traversal**: keep rooms solid (current) or vazgriz-style allow pathing through rooms at +5 cost (changes endpoints to room centers)?
5. **`floor_count` default**: 1 (= today's behavior), or 3?
6. **Failed edges**: silently skip (vazgriz) + optional debug print?
7. **Stair mesh strategy**: ONE stair instance per 2×2 block (recommended — mesh is a full flight) with GridMap item 4 on all 4 cells — OK?
8. **Debt first?**: fix `queue_free` persistence + stale DunMesh instances + wire `hide_grid_map_after_build` before/with this work?
9. **Top/bottom**: ceiling slab above top floor? border walls on every floor y?

---

## 7. Log / decisions

- *(none yet — awaiting answers to §6)*
