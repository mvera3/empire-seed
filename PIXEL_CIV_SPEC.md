# Empire Seed — Build Spec (Offline Edition)

> **Developer / Studio:** Arcanoire Studio

> A spec document for Claude Code. This is a **pure offline, single-player** game. No backend, no accounts, no servers, no cloud. All state lives on the device. Follow the phased build order at the bottom — do not jump ahead to combat or local multiplayer before the core builder loop is solid.

---

## 1. Concept

An offline, pixelated civilization builder. The player grows a base from a primitive settlement into a thriving civilization by gathering tiered resources, processing them, upgrading buildings and defenses, and training an army. The world map is filled with **endless, procedurally generated NPC bases** of scaling difficulty. Early on the player is far too weak to attack them — so the game is a survival-and-growth grind: gather, build, strengthen, then conquer tougher and tougher bases as the civilization advances through eras.

The emotional hook: a base that is always *yours*, that grows under your hands, in a world that always has a tougher challenge waiting when you're ready for it.

---

## 2. Core Pillars

1. **Pure offline.** Everything runs and saves locally. No network required, ever.
2. **The grind is the game.** Gather -> process -> build -> train -> conquer -> advance. This loop must feel satisfying on its own.
3. **Endless scaling challenge.** Procedurally generated NPC bases mean infinite content with zero infrastructure.
4. **Earned power.** Early NPC bases are deliberately brutal. You cannot win without grinding first — that struggle *is* the survival/civilization fantasy.
5. **Timeless pixel art.** A tight, cohesive 16-bit aesthetic that ages well.

---

## 3. Art Direction

- **Style:** 16-bit. Rich, animated sprites; iconic and restrained. (Reference: *Stardew Valley*, *Final Fantasy VI*.)
- **Palette:** Lock a cohesive 32-48 color master palette early. Every asset draws from it — this consistency is the biggest factor in art aging well.
- **Perspective:** Top-down or 2:1 isometric on a fixed grid. Pick one, never mix.
- **Era visuals:** The base visually transforms as the player advances eras (huts -> brick -> industrial). Same footprint, evolving skin.
- **UI:** Clean, chunky pixel UI with modern readability. Resource counters always visible.

---

## 4. Resource System

Tiered resources gate progression so it feels earned.

**Tier 1 — Raw (gathered directly):** Wood, Stone, Food, Water
**Tier 2 — Mined/refined:** Iron Ore, Coal, Copper Ore, Clay
**Tier 3 — Processed (buildings convert lower tiers):** Steel (iron ore + coal), Tools, Bricks (clay), Planks (wood)
**Tier 4 — Premium:** Gold (slow trickle + NPC battle rewards), for high-end upgrades and wonders

**Rules:**
- Production buildings consume lower tiers to output higher tiers (e.g. Smelter: iron ore + coal -> steel).
- Every resource has its own **upgradable storage** with a hard cap. Production halts when storage is full, making storage upgrades a real strategic decision.
- Resources accumulate offline (see section 11 Offline Progression).

---

## 5. Buildings

All infinitely upgradable, with costs scaling on a soft-cap curve (late upgrades aspirational, not impossible).

- **Production:** Farm, Lumber Camp, Quarry, Mine, Water Pump
- **Processing:** Smelter, Workshop, Brick Kiln, Sawmill
- **Storage:** Per-resource or grouped warehouses, upgradable capacity
- **Defense:** Walls, Towers, Traps, Gate (matters for local-PvP defense and gives a sense of fortification)
- **Military:** Barracks (train units), Army Camp (houses units)
- **Civic:** Town Hall (gates era advancement + overall level)
- **Wonders:** Prestige mega-buildings — see section 9

Each upgrade: costs resources, takes build time (with a queue), shows a clear before/after stat delta.

---

## 6. The World Map & NPC Bases

The core combat content. Fully offline and procedurally generated.

**Map structure:**
- A scrollable world map radiating outward from the player's home base.
- NPC bases are scattered across it, **endless** — generate more as the player explores outward.
- **Difficulty = mix of player power AND map distance.** Bases near home scale to stay relevant to the player's current power (always a fair fight available). Bases farther out are harder regardless — venturing into the frontier means tougher enemies and better loot. This gives both a steady supply of winnable fights *and* a high-risk/high-reward frontier.

**Per-base generation:** Each NPC base has a procedurally generated layout, defense strength, army, a **difficulty rating** (shown before attacking), and a **loot preview** (what you can win). The player scouts, then chooses whether to attack — informed decisions, not blind gambles.

**Early-game intent:** Bases should be genuinely too strong for a fresh player to beat. The player must grind gathering, building, and army training before the first real victories. This is the intended difficulty curve, not a bug.

**Combat resolution:** Deterministic simulation based on the player's army + the base's defenses. Can be a watchable auto-battle (army marches in, fights, you watch it play out) — simple to build, satisfying to watch, and shareable as screenshots.

**Battle outcomes:**
- **Player wins:** Takes the base's loot (resources, gold). Surviving army returns; lost units are gone. Base can respawn/refresh over time so the map stays populated.
- **Player loses:** **Loses the committed army + some resources.** Meaningful stakes — failure costs you — but no base-repair spiral, so a loss never makes the player want to quit.

---

## 7. Local Multiplayer (Optional — Build Last, or v2)

No internet, no servers. Purely device-to-device.

- Two players on the **same WiFi network or a phone hotspot** can discover each other (local network discovery / Bluetooth / Wi-Fi Direct depending on platform support).
- One sends a **direct challenge**; the other accepts or declines.
- On accept, the two devices exchange base/army snapshots and run the **same deterministic battle simulation** locally.
- This is a bonus feature. It must not complicate the core single-player build. **Defer it to the very end or a later version.**

---

## 8. Era / Tech Progression

Advance through ages, gated by Town Hall level + resource/research costs:

**Stone -> Bronze -> Iron -> Industrial** (extend later)

Each era unlocks new buildings, units, and recipes, and visually transforms the base — giving infinite expansion a sense of *arrival* rather than just bigger numbers.

---

## 9. Wonders

Expensive, prestige mega-buildings with unique civ-wide bonuses and long build times. Endgame goals.

Examples: **Great Library** (research speed), **Colossus** (defense), **Hanging Gardens** (food), **Great Forge** (steel output). Cap how many a player can hold to force meaningful choices.

---

## 10. Additional Systems

- **Daily/quest system:** Light objectives that reward resources and structure the grind.
- **Dynamic events:** Occasional droughts, bonus harvests, or wandering merchant caravans (limited-time resource swaps) to keep the offline world feeling alive.
- **Achievements & milestones:** Local-only, for long-term goals (first Iron-era base conquered, first Wonder built, etc.).
- **Conquest log / map progression:** Track how far into the frontier the player has pushed.

---

## 11. Persistence & Offline Progression

- **Save model:** Local-first. The local save is the source of truth — the game is always fully playable with zero connection. Use the platform's local storage (e.g. local files / SQLite / Godot's user:// save system).
- **Offline accrual:** When the player closes and reopens the game, calculate elapsed real time and grant accumulated production (capped by storage limits). This is the standard idle-builder mechanic and is essential for an offline grind game to feel rewarding. Build this into the save system from Phase 1.
- **Cloud backup (automatic):** Back up the local save to the player's own platform account so progress survives reinstall or a new device:
  - **Android:** Google Play Games Services — Saved Games (cloud save). Free, syncs to the player's Google account.
  - **iOS:** iCloud / Game Center saved games. Free, syncs to the player's Apple account.
  - This is **backup only** — gameplay never requires a connection. The save uploads opportunistically when the device is online. This costs nothing (the platform hosts it, not you) and is NOT a backend.
- **Manual export/import (offline fallback):** A "Backup" button that exports the save as a file or copyable code, and a "Restore" button that reads it back. Players store it wherever they like (cloud drive, email, notes). 100% offline, and a safety net for players who don't use platform cloud save.
- **Recovery flow:** On a fresh install, check for a platform cloud save first and offer to restore; also expose manual import in settings.

---

## 12. Tech Stack

> A 2D pixel game with no backend is simple to stack. The engine is decided: **Godot 4.**

- **Engine:** Godot 4 (locked in) — free, open source, no licensing fees, excellent 2D/pixel pipeline, one-click export to Android/iOS/desktop.
- **Language:** GDScript (Godot's native language — best for this project; C# is available if a specific need arises, but default to GDScript).
- **Storage:** Godot's built-in user:// save system for the save blob, or SQLite (via a Godot addon) if structured queries on buildings/map state become useful. Start with user:// + JSON; only move to SQLite if it's actually needed.
- **Rendering:** Set the project to a low base resolution with integer scaling and disable texture filtering (nearest-neighbor) so pixel art stays crisp at every screen size.
- **No backend, no auth SDK, no networking libraries** — except:
  - Cloud backup uses the platform plugins (Google Play Games Services / Apple Game Center) in Phase 5.
  - Optional Phase 6 local-multiplayer uses Godot's built-in high-level multiplayer over local network only.

---

## 13. Data Model (starting point)

```
GameState {
  player: {
    era, townHallLevel, totalPower
    resources: { wood, stone, food, water, ironOre, coal, ... }
    storageCaps: { wood, stone, ... }
    gold
  }
  buildings: [ { type, level, gridPos, buildFinishAt } ]
  army: [ { unitType, count } ]
  map: {
    exploredRadius
    bases: [ NpcBase ]        // generated lazily as player explores
    seed                       // for reproducible procedural generation
  }
  lastPlayedAt                 // for offline accrual calculation
  achievements, questProgress
}

NpcBase {
  id, gridPos, distanceFromHome
  difficultyRating
  layout, defenseStat, army
  lootPreview: { resourceType: amount, gold }
  defeated (bool), respawnAt
}

Building {
  type, level, gridPosX, gridPosY
  productionRate, storageBonus, defenseStat
  upgradeCost, upgradeFinishAt
}
```

---

## 14. Phased Build Order

**Build in this order. Each phase must be playable before moving on.**

**Phase 1 — Core Builder:**
- Grid + camera + tap-to-place.
- Tier 1 resource gathering + storage with caps.
- 4-5 buildings with upgrade + build queue.
- Local save/load + offline accrual.
- *Goal: a satisfying self-contained base builder.*

**Phase 2 — Economy depth:**
- Tier 2-4 resources + processing buildings.
- Era progression (Stone -> Bronze -> Iron).
- Tech tree / research.

**Phase 3 — Army & Map:**
- Military buildings + unit training.
- World map with procedurally generated NPC bases (difficulty = power + distance).
- Scouting (difficulty rating + loot preview).

**Phase 4 — Combat:**
- Deterministic battle simulation + watchable auto-battle.
- Win/loss economy (win loot; lose army + resources).
- NPC base respawn/refresh so the map stays populated.

**Phase 5 — Endgame & retention:**
- Wonders.
- Daily quests, dynamic events, achievements.
- Cloud backup (Play Games / iCloud saved games) + manual export/import + recovery flow.

**Phase 6 — Local Multiplayer (optional / v2):**
- Local-network or hotspot device discovery.
- Direct challenge -> accept/decline -> shared local battle sim.

---

## 15. Non-Negotiables (guardrails for the build)

- The game is **always** fully playable offline. No feature may require a network connection — the only network use permitted is opportunistic cloud *backup* (platform saved games), which never gates gameplay. (Optional Phase 6 local-only PvP is the one exception, and it uses local network only.)
- The local save is **always** the source of truth; cloud/manual backup never becomes a gameplay dependency.
- Early NPC bases are **always** hard — the grind is intended, not a balancing accident.
- A player loss costs **army + some resources** — never a base-repair spiral.
- Offline production **always** accrues on return (capped by storage).
- Art **always** draws from the locked master palette.
