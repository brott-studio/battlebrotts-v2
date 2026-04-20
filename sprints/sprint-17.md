# Sprint 17 — Eve Polish Arc

**PM:** Ett
**Status:** Planning (iteration 1 of S17)
**Sprint type:** Multi sub-sprint UX polish arc
**Iteration sizing target:** S17.1 medium, S17.2 medium, S17.3 medium-large

---

> ## 🛑 SCOPE GATE — READ FIRST
>
> **NO behavior changes to `godot/combat/**` gameplay code (esp. `combat_sim.gd`, `brott_state.gd`) UNLESS the wall-stuck bug traces there as root cause.**
>
> **NO balance changes to `godot/data/**` (`weapon_data.gd`, `chassis_data.gd`, `armor_data.gd`, etc.).**
>
> **NO edits to `docs/gdd.md`.**
>
> This is a **polish/UX/feel arc**, not a mechanics arc. Every behavior change must trace to:
> - A playtest-flagged UX issue (see Citations column below), OR
> - A concrete bug (wall-stuck navmesh issue), OR
> - Scout-feel tuning (acceleration/angular-velocity smoothing, NOT base speed or combat numbers).
>
> If a sub-task drifts into "let's also change X while we're here" — STOP and carry-forward to a future gameplay arc. Scope-gate discipline held clean across S15.2 → S16.1 → S16.2 → S16.3. Don't break the streak.

---

## Goal (condensed from HCD charter)

Convert the current playable-but-rough build into something that feels **professional, clean, and polished** (HCD's "Eve from WALL-E" vision per `docs/kb/ux-vision.md`). Ship changes that address 2026-04-18 playtest feedback so the next playtest is about mechanics, not UI friction.

**Source of truth:** the 2026-04-18 playtest notes (HCD-authored, captured at `memory/2026-04-20.md` §18:23). Nearly all UX complaints already filed as backlog issues #94–#123. Four findings are net-new to this arc and don't have issues yet.

**Acceptance for the S17 arc as a whole (HCD bar):**
- HCD replays the current build post-arc and does NOT hit the frustrations from the original playtest notes (scroll/overlap/energy-bar confusion/scout-mice-feel/wall-stuck/BrottBrain-drag).
- Scout movement reads as "brott" not "mouse" in HCD's subjective read.
- Bots don't get stuck on walls.
- BrottBrain is recognizably fun to interact with (drag works, delete is clear, card library is curated).
- Playtest-ready drop at end of arc.

---

## Sub-sprint breakdown

S17 is split into three sub-sprints. **Sequential by default** (S17.1 → S17.2 → S17.3) but S17.2 and S17.3 have no hard dependency; they could run in parallel if Riv judges it safe and HCD has not objected. Default to sequential.

| Sub-sprint | Theme | Exit criterion | Expected size |
|---|---|---|---|
| **S17.1** | Shop/Loadout/Event UX fixes | All cited backlog UX issues either resolved or explicitly deferred with HCD-visible rationale | Medium (5–6 tasks) |
| **S17.2** | Scout feel + wall-stuck bug triage | (a) Wall-stuck bug fixed OR root-caused + minimal patch. (b) Scout movement qualitatively "weighty brott" in Optic visual check | Medium (2–3 tasks) |
| **S17.3** | BrottBrain UI + card library curation | Drag works, delete is clear, card library curated (low-value removed, missing-but-used surfaced), PRs #76/#77 triaged | Medium-large (4–5 tasks) |

Ett will re-spawn per iteration to emit each sub-sprint's individual plan file (`sprint-17.1.md`, etc.) once the prior audit lands. **This file is the arc-level plan.**

---

## S17.1 — Shop/Loadout/Event UX fixes

**Goal:** Remove the top UX friction points from the 2026-04-18 playtest. "Clean, professional, polished" per ux-vision.md.

### Citations (playtest → backlog)

| Playtest complaint (verbatim-ish) | Backlog issue | Priority |
|---|---|---|
| "very hard to scroll in the shop - scrolls too fast" + "whenever i click something in the shop it shoves me all the way back to the top of the screen" | #105 | high |
| "in loadout when i have a lot of stuff they cover the shop button" | #104 | high |
| "in loadout view there's no way to double check what an item is or does" (later found hover works) | #103 | high |
| "i'm confused what the blue bar is - is that energy? What is energy for?" | #107 | mid |
| "the popup asking for trading or opening crates is kind of annoying" + "the random events with decision are pretty chaotic, taking my items" | #106 | mid |
| "the screen asking whether i want to open a crate was jarring to be the first thing i see" | #107 (broader) | mid |

### Tasks (Ett finalizes during S17.1 planning iteration)

Sketch only; Gizmo will convert to technical spec:

- **[S17.1-001]** Shop scroll behavior — respect OS scroll speed, preserve scroll position on item click. (#105)
- **[S17.1-002]** Loadout UI overlap fix — shop button always accessible regardless of inventory count. (#104)
- **[S17.1-003]** Tooltips visible-by-default for critical info (at minimum: item stats, energy bar meaning). (#103, #107)
- **[S17.1-004]** First-encounter HUD explanation — energy bar in particular. One-sentence explainer on first view, dismissible. (#107)
- **[S17.1-005]** Random-event popup polish — skippable or rarer; follow ux-vision.md anti-pattern guidance. (#106)
- **[S17.1-006]** First-run crate decision — contextualize or defer; "jarring first screen" complaint. (#107 adjacent)

**Acceptance:**
- All 6 tasks either land or get HCD-visible defer notes.
- Optic Playwright run confirms no regressions in shop/loadout screens.
- Scope gate held (no combat/data/GDD touches).

---

## S17.2 — Scout feel + wall-stuck bug triage

**Goal:** Fix the immersion-breaking movement complaints. This is the highest-stakes sub-sprint for "does the game feel good."

### Citations (playtest → findings)

**From playtest, not yet filed as issues:**
1. "scout still feels a little bit too fast to follow. or maybe it's the changing directions is so fast, it makes it feel like I'm watching mice run around rather than weighty brotts" + "the way scout moves is so crazy fast, ruins the robot feel" + "its movements are very jerky too"
2. "occasionally bots stop moving... it's always next to a wall, i think they get stuck on walls? happened again, sometimes only to one bot - gets stuck on a wall and can't move"
3. "Toward the last 5 or so shots, both bots stopped moving and just shot at each other - is this a bug?" (possibly same root cause as #2, or separate end-game disengagement)

### Tasks

- **[S17.2-001]** Wall-stuck bug triage. Root-cause investigation FIRST (Gizmo diagnosis). Likely navmesh edge case. Document finding as KB entry before patching. Check if it explains the "last 5 shots stop moving" complaint too.
- **[S17.2-002]** Wall-stuck minimal patch. Once root-caused, smallest safe change that unblocks the stuck bot. Do NOT refactor pathfinding; scope-carry if it's a larger problem.
- **[S17.2-003]** Scout movement feel pass. Smooth angular velocity / commit-to-direction for ~100-200ms before 180°-flipping. Preserve agility (Scout should remain the most agile chassis). Must pass an Optic visual diff comparison: old-Scout vs new-Scout in same scenario, both archive screenshots/videos for HCD judgment.

**Acceptance:**
- Wall-stuck bug fixed OR quarantined with filed carry-forward issue + root-cause documented.
- Scout "mice → brott" feel shift confirmed by Optic + (ideally) HCD spot-check before arc close.
- Zero combat-balance number changes in `godot/data/**`.

**Gizmo invariant:** S17.2-003 is the most design-inflected task in this arc. Gizmo must explicitly note:
- What the new angular velocity cap / commit window values are.
- Why those values (reference playtest feel language + existing Scout role in GDD).
- Any delta to Scout's agility-archetype identity.

---

## S17.3 — BrottBrain UI + card library curation

**Goal:** BrottBrain was "almost fun" in playtest — highest-leverage signal in the notes. Take it to fun. Plus: resolve the two stale PRs from S14.2.

### Citations

**Playtest:**
- "It says drag but I can't drag (managed to click a when card then a then card to add something)" → drag is broken
- "the delete button was very unintuitive" → delete interaction needs redesign
- "it didn't have some things i wanted like charge or chase after" → missing cards (CHASE is partial overlap with backlog #116 GET_TO_COVER)
- "and it had a lot of things i didnt really want like clock time and others" → card library curation (low-value pruning)
- "thinking about and crafting cards was actually kind of fun, but it didn't have some things i wanted" → the loop works; the content doesn't

**Also in scope:** stale PRs #76 (BrottBrain UI polish) and #77 (aggression cards + library audit) from S14.2. Open ~1 week, no updates. First step of S17.3: triage these.

### Tasks

- **[S17.3-001]** Stale PR triage. Riv (or delegate) investigates PRs #76 and #77. Three possible outcomes: (a) rebase and revive into S17.3, (b) close with rationale, (c) cherry-pick salvageable parts. **HCD-visible decision** — ping HCD before executing option (b) if either PR contains non-trivial work.
- **[S17.3-002]** Fix drag behavior in BrottBrain UI. End-to-end — if drag is broken in a specific way, that's a bug, not a design call. Don't redesign the whole UX.
- **[S17.3-003]** Delete interaction redesign. Per ux-vision.md pillars. Keep minimal.
- **[S17.3-004]** Card library curation. Audit every card currently in the library:
  - **Cut:** "clock time"-class low-value cards that are noise.
  - **Surface or implement:** CHARGE, CHASE (see backlog #116 for GET_TO_COVER overlap — decide if CHASE is a rename or a new card).
  - **Keep:** existing high-value cards.
  - Deliverable: a card-library roster diff with rationale per add/remove, committed as a KB doc.
- **[S17.3-005]** (If time) End-to-end BrottBrain flow polish: the thinking-about-cards loop HCD said was "almost fun" — tighten feedback/iteration speed.

**Acceptance:**
- Drag works end-to-end (Playwright test added).
- Delete interaction is 1-click-from-obvious.
- Card library curation landed as KB doc + code change.
- PRs #76/#77 decisively resolved (one of revive/close/cherry-pick).

**Gizmo invariant:** card library is content design. Gizmo designs the roster; Nutts implements. Don't let Nutts cut or add cards autonomously.

---

## Explicitly out of scope for S17

- Net-new chassis or weapons
- Bronze league content population (#112)
- Audio foundation (#94)
- Art swap-ins (#98–#100)
- Balance number re-tuning (no complaint in playtest said numbers were off)
- GDD rewrites
- Combat sim logic (unless wall-stuck bug traces there)

Anything in this list that gets proposed mid-arc: carry-forward issue filed, NOT executed in S17.

---

## Sacred (do-not-touch unless explicitly scoped)

- `godot/combat/**` (combat_sim, brott_state) — only S17.2 wall-stuck may touch, and only with Gizmo sign-off
- `godot/data/**` (weapon/chassis/armor data) — no changes
- `godot/arena/**` — no changes
- `docs/gdd.md` — no changes
- Balance files — no changes
- Test suite assertions that currently pass — no loosening

---

## Framework gates (from S16 arc-complete retrospective)

- **Audit-gate invariant (new in PIPELINE.md):** each sub-sprint N.M is NOT closed until `audits/battlebrotts-v2/v2-sprint-17.M.md` lands on `studio-audits/main`. Riv/Ett must treat this as a hard precondition for starting N.(M+1).
- **Per-agent App usage:** Specc App (ID 3444613, Install 125608421) continues in production use for S17 audits and any Specc-authored PRs. Boltz continues with shared-PAT COMMENT-fallback; per-agent App for Boltz is deferred HCD action, not in S17 scope.

---

## Pipeline flow

Standard pipeline for each sub-sprint: Ett plans → Gizmo design (task-by-task) → Nutts build → Boltz review → Optic verify → Specc audit → Gizmo design-validation → Ett continuation decision → Riv loops.

**Critical:** for S17.2-003 (Scout feel) and all of S17.3 (BrottBrain), Gizmo is the most important role. Design-first. No "let's just ship and iterate" — these are the tasks where feel matters, and feel comes from design intent, not from post-hoc tweaking.

---

## Escalation triggers (Riv → The Bott → HCD)

Auto-surface to HCD via The Bott if:
- Scope-gate violation proposed (someone wants to change combat/data/gdd).
- Wall-stuck bug root-causes to a combat_sim change that would violate scope gate.
- Scout feel change proposes a base-speed or agility-archetype redefinition.
- Stale PR #76 or #77 has non-trivial work that option (b) (close) would discard — need HCD call.
- Card library curation removes/renames a card that has GDD reference.
- Sub-sprint exceeds 2× expected size.
- Any test suite regression that would require quarantining a currently-passing test.

Otherwise: Riv and Ett operate autonomously per 2026-04-20 autonomy directive.

---

## Carry-forward backlog (populated during arc)

*(Entries added by Ett as sub-sprints surface non-scope findings.)*
