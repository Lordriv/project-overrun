# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**ProjectOVERRUN** is a cooperative 3D wave-based survival shooter built in **Godot 4.6** (GDScript). Up to 4 players fight endless enemy waves with Firebase-powered multiplayer and an augment (passive upgrade) progression system.

## Development

**Engine**: Godot 4.6 with Forward Plus rendering and Jolt Physics.

**Running the project**: Open in Godot 4.6+ and press Play. The main scene is `scenes/ui/main_menu.tscn`. If no Firebase session exists, the game automatically injects a debug solo player so the full game loop runs without a live session.

**Exports**: Configured in `export_presets.cfg` (Windows, iOS). Use Godot's built-in export dialog.

There is no build CLI, linter, or test suite — all iteration happens inside the Godot editor.

## Architecture

### Autoloaded Singletons (Global Managers)

All persistent state lives in autoloads registered in `project.godot`. These are the most important files to understand:

| Singleton | File | Role |
|---|---|---|
| `PlayerAccount` | `scripts/firebase/player_account.gd` | Local identity, Firebase auth, save/load `user://player_data.json` |
| `SessionManager` | `scripts/firebase/session_manager.gd` | Create/join multiplayer sessions, poll Firebase for join/leave (2s interval) |
| `WaveManager` | `scripts/systems/wave_manager.gd` | Spawn enemy waves with exponential scaling (cap: 20 enemies) |
| `EnemyManager` | `scripts/enemy/enemy_manager.gd` | Enemy registry, player targeting lookups |
| `PlayerSpawner` | `scripts/systems/player_spawner.gd` | Instantiate player characters at spawn points |
| `PlayerData` | `scripts/character/player_data.gd` | In-memory player stats (HP, shields, max wave); synced via `PlayerAccount` |
| `AugmentPool` | `scripts/augments/augment_pool.gd` | Available augment selection pool |

### Scene Flow

```
main_menu.tscn → Lobby.tscn → world.tscn
                 (cinematic)   (wave combat loop)
```

- **Lobby** (`scripts/world/lobby.gd`): Squad assembly. Late-joining players drop in via chute spawns. Plays intro cinematic before transitioning.
- **World** (`scripts/world/world.gd`): Reactively spawns/despawns player characters based on `SessionManager` state. Calls `WaveManager` to start runs. On all players downed → death loop → respawn.

### Component-Based Character System

The player character (`characters/character.tscn`) composes several script components:

- `scripts/character/character_body_3d.gd` — Movement controller: WASD, mouse look, sprint, dash, knockback physics
- `scripts/components/health_component.gd` — HP/shield state machine: alive → downed → dead
- `scripts/damage/weapons/weapon_component.gd` — Firing, ammo, reload, projectile spawning
- `scripts/damage/weapons/weapon_holder.gd` — Manages equipping/swapping multiple weapons
- `scripts/components/aggro_component.gd` — Threat detection radius for enemies

### Combat & Enemies

Enemies (`scripts/enemy/enemy.gd`) chase the nearest player via `EnemyManager` lookups and deal contact damage. Projectiles (`scripts/damage/projectiles/projectile.gd`) support both hitscan and ballistic modes.

### Augment System

Augments are `.tres` resource files under `resources/augments/`. Each defines a stat modifier (fire rate, max HP, knockback, etc.). `AugmentPool` surfaces a random selection after each wave via `AugmentPickUI`.

### Firebase Backend

`scripts/firebase/` wraps the `godot-firebase` addon with a thin `FirebaseHelper` (HTTP/REST calls). Real-time session sync uses the `http-sse-client` addon (Server-Sent Events). Player data persists to Firestore; session state lives in the Realtime Database.

## Files Changed Most Often

- `scripts/systems/wave_manager.gd` — difficulty tuning, wave composition
- `scripts/augments/` + `resources/augments/*.tres` — adding or balancing augments
- `scripts/ui/hud.gd` — HUD layout and display logic
- `scripts/character/character_body_3d.gd` — player feel (movement, dash, knockback)
- `project.godot` — adding autoloads, input actions, or physics settings
