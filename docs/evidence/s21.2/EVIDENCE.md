# S21.2 Playwright Screenshot Evidence

Captured by Optic on 2026-04-24. Addresses #247 (screenshot evidence not captured in original run).
Code merged: PR #244 (commit `179f660a`).

## Method

Screenshots captured via Playwright against a local Godot 4.4.1 Web export of `main` (179f660a).
Export method: `godot --headless --export-debug "Web"`. Served at localhost:8766.
URL routing (`?screen=brottbrain`, `?screen=opponent`, `?screen=loadout`, `?screen=shop`) added to
`game_main.gd` for direct screen access — evidence-only test hook, no game logic change.

CI context: Godot unit tests 42/42 pass on main. Playwright smoke pass on main.
Boltz spec conformance: review 4165671939.

---

## Screenshots

### T1 #104 — ScrollContainers

**`s21.2-URL-brottbrain.png`** — BrottBrain Editor showing the Available Cards tray (TrayScroll).
The WHEN/THEN card rows below the priority list are wrapped in TrayScroll so they scroll
horizontally when content overflows. Trigger cards and action cards visible with inline captions.

**`s21.2-URL-opponent-select.png`** — OpponentSelect screen showing three opponent panels in the
ListScroll container. ListScroll wraps the panel list so 5–6 opponents (with #103 subtitle
inflation) don't overflow into the Back button at y=650.

---

### T2 #103 — Inline Captions

**`s21.2-URL-brottbrain.png`** — Trigger card captions visible below each WHEN card:
"Fires when HP drops below threshold", "Fires while HP stays above threshold",
"Fires when energy drops below threshold", etc. (all 11 trigger captions present).
Action card captions visible below each THEN card:
"Change Stance to picked behavior", "Activate equipped module gadgets",
"Re-prioritize who to attack", etc.

**`s21.2-URL-opponent-select.png`** — Opponent archetype subtitles in blue text:
- "Aggressive — closes fast and brawls. Light frame."
- "Defensive — holds ground, trades carefully. Light frame."
- "Kiting — keeps distance, chips you down. Heavy frame."

**`s21.2-URL-loadout.png`** — Loadout weight caption: "7 kg headroom before slowdown."
displayed inline next to the weight bar (23/30 kg).

---

### T3 #107 — First-Encounter Overlays

**`s21.2-URL-shop-fe-overlay.png`** — `shop_first_visit` FE overlay:
"🛍️ Welcome to the Shop. Spend Bolts on chassis, weapons, armor, and modules — then head to Loadout."
with "Got it!" dismiss button. Overlay appears on first shop visit.

**`s21.2-URL-brottbrain.png`** — `brottbrain_first_visit` FE overlay:
"🧠 BrottBrain teaches your bot what to do. Build WHEN → THEN rules from the tray below."
with "Got it!" dismiss button. Visible alongside the BrottBrain editor.

**`s21.2-URL-opponent-select.png`** — `opponent_first_visit` FE overlay:
"⚔️ Pick an opponent to fight. Beating all 3 in this league unlocks the next tier."
with "Got it!" dismiss button.

---

## CI Reference

Playwright smoke run on main (commit 179f660a): run ID 24857656774 — all checks pass.
Godot unit tests on main: 42/42 files pass (run ID 24857656774, job 72774738143).

Closes #247.
