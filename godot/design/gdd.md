# BattleBrotts Game Design Document

*This file is owned by the studio pipeline. Sections are added per sprint.*

---

## League Scaling — Player-Side Degradation

**Core principle.** Certain player defensive systems degrade as the player advances through leagues. This is an intentional progression tax: the climb costs something, and the player should feel it. Higher leagues are not simply harder opponents — they are environments where the player's current kit reads differently.

**Why player-side, not opponent-only.** S22.2b (2026-04-24) established the failure mode of opponent-only scaling. When opponents are tuned to compensate for a symmetric mechanic (both player and opponent benefit from Reactive Mesh reflect), the opponent pool loses archetype coherence — Brawler-wall templates shed their identity characteristic (Reactive Mesh) to suppress a damage number. The correct fix is a data-layer table at the mechanic's read-site so the mechanic itself degrades with league, leaving opponent loadouts free to be authored for archetype clarity.

**Bronze as canonical baseline.** All player defensive systems are at full strength in Bronze. Bronze is the design anchor — the league where each armor and module reads as intended. Balance tuning and WR targets for new armor/module introductions should be validated at Bronze first.

**Current implementation — Reactive Mesh reflect damage:**

| League     | Reflect HP per hit | Notes                          |
|------------|-------------------|--------------------------------|
| Scrapyard  | 5.0               | Pre-Bronze; matches Bronze     |
| Bronze     | **5.0**           | Canonical baseline — immutable |
| Silver     | 2.0               | Degraded; ~40% of Bronze       |
| Gold       | 1.0               | Future-proof (not yet live)    |
| Platinum   | 0.0               | Mesh "broken" — narrative arc  |

Implemented via `ArmorData.REFLECT_DAMAGE_BY_LEAGUE` dictionary + `reflect_damage_for_league(type, league)` helper. Combat-sim reads league from `BrottState.current_league` (default `"bronze"` for back-compat). One-line read-site change; no engine logic touched.

**Extensibility.** Dictionary pattern is open by key. Future tier-5 "Storm Mesh" armor with its own reflect curve registers a new entry without modifying the helper or the sim. Future defensive modules — Repair Nanites uptime, Overclock cooldown — follow the same per-league table pattern.

**Narrative-coupling rule.** Any player-side degradation introduced at a new league boundary must ship with a one-line modal beat on league entry explaining it. Silent nerfs are prohibited. S22.2c ships this for Silver via `league_complete_modal.gd` copy: *"Reactive mesh loses its teeth up here. Silver runs hotter."*
