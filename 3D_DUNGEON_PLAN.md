# 3D Dungeon + Stairs — Analysis & Plan

> **STATUS: IMPLEMENTED — awaiting scene edits + in-editor test.**
> All generation code written in GDScript; self-test passed (see §7).
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

Language note: project runs **Godot 4.8 dev6 mono**, but decision is **all GDScript** (no `.csproj`
exists; C# would need an assembly build we cannot test headless + GDScript↔C# interop risk).
Only available test binaries are Godot 4.7/4.7.1 (see §7).

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

## 5. Implementation (DONE — see §7 for file list)

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

### Generation timing — DECIDED: editor bake (`@tool`) kept
- Stays on the current `@tool` + Start-toggle workflow (matches "user does all scene edits").
- Persistence bug fixed instead: `dungeon_cell.gd` now uses **`free()`** (reference-tutorial behavior).

---

## 6. Open questions — ANSWERS (all resolved)

1. **Language**: GDScript (B) — no `.csproj`, headless C# build untestable here. ✔
2. **Generation timing**: editor bake `@tool`, persistence fixed via `free()` (see §5). ✔
3. **Rooms**: single-floor rooms only (y = random in `0..floor_count-1`, height 1). ✔
4. **Room traversal**: rooms stay **solid** (no +5 pathing). Endpoints = closest perimeter tile. ✔
5. **`floor_count` default**: **3** (exported, editable in inspector). ✔
6. **Failed edges**: silently skipped, one summary print of carved/failed counts. ✔
7. **Stair mesh**: ONE instance per 2×2 block, item 4 on all 4 cells. ✔
8. **Debt**: fixed alongside — `free()`, `hide_grid_map_after_build` + `remove_cell_collision`
   now wired; componentwise `cell_size` (multi-floor Y). *Stale 256-spacing DunMesh instances in
   the scene still need a regen (next Start bake replaces them anyway).* ✔
9. **Top/bottom**: border walls on every floor; no extra ceiling slab above top floor (cell art
   ceiling already closes each level). ✔

---

## 7. Log / decisions

### 2026-09-25 — implementation complete (code), self-test passed

| File | Action |
|---|---|
| `dungeon-generation/delaunay_3d.gd` | **NEW** `DunDelaunay3D` — Bowyer-Watson tetrahedralization, circumspheres, degenerate-tet guard, canonical `Vector2i(min,max)` edge list |
| `dungeon-generation/dungeon_pathfinder_3d.gd` | **NEW** `DunPathfinder3D` — 4 flat + 8 stair neighbors, per-node `PreviousSet`, rooms/borders solid, None +1 / stair 100+heur, 4-cell stair safety, empty array = failed edge |
| `dungeon-generation/dungeon.gd` | **REWRITTEN** — `floor_count` export (def 3), per-floor border, 3D `make_room` (random y), 3D delaunay w/ coplanar 2D fallback, 3D Prim + `survival_chance`, `_pathfind_hallways` (door temp-set, carve None→1, vertical step → 4× item 4, summary print) |
| `dungeon-generation/dungeon_mesh.gd` | **EDITED** — item 4 handled (type normalized 1 in handle matrix), stair shaft openings (remove ceiling/floor), `_maybe_place_stair` (c1 detection, midpoint × cell_size, yaw table, `STAIR_ASCENDS_ALONG_POSITIVE_X` const), `dungeon_stair_scene` export, `hide_grid_map_after_build` + `remove_cell_collision` wired, componentwise `Vector3(cell) * grid_map.cell_size` |
| `dungeon-generation/dungeon_cell.gd` | **EDITED** — `queue_free()` → `free()` (persistence fix), added `remove_ceiling()` / `remove_floor()` |
| `dungeon_selftest.gd` | **NEW (temporary)** — headless regression test, all passed |

**Verification** (Godot 4.7.1 headless, `--script dungeon_selftest.gd`, exit 0):
- delaunay: 55 unique edges / 16 random points, no dupes/self-loops, range-safe
- pathfinder: path across 2 floors with 1 stair jump, correct (3h + 1y) step shape
- generate: 18 rooms on ≥2 floors, 21/21 edges carved (0 failed), 56 stair cells (= 14 × 2×2),
  39 doors, items only in {-1,0,1,2,3,4}
- fixed en route: `Vector3.max_axis()` doesn't exist → `maxf()` chain; `var d := load(...)` type
  inference error → untyped `=`

**Known caveats**
- Stair scene assumed to ascend along world **+X**; if placed stairs run downhill, set
  `STAIR_ASCENDS_ALONG_POSITIVE_X = false` in `dungeon_mesh.gd` (top of file).
- Godot 4.8 editor not runnable here → final validation is the user's in-editor bake.
- Command-line note: Godot GUI binaries need `Start-Process -Wait` (or output redirection) from
  pwsh; plain `&` doesn't wait/capture.
