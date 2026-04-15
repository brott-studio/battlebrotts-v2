# Pattern: Behavior Card System (BrottBrain)

**Source:** Sprint 2 — BrottBrain implementation  
**Category:** Game AI

## The Pattern

A simple, ordered list of `trigger → action` cards evaluated top-to-bottom each tick. First matching trigger fires its action. No complex state machines, no behavior trees.

```
Card 1: WHEN I'm hurt (< 30% HP) → Switch to Defensive stance
Card 2: WHEN they're hurt (< 30% HP) → Switch to Aggressive stance
Card 3: WHEN gadget ready → Use Repair Nanites
```

## Why It Works

- **Priority is implicit** — card order = priority. No weight tuning needed.
- **One card fires per tick** — prevents conflicting actions.
- **Player-understandable** — "if this, then that" is intuitive. No hidden logic.
- **Emergent complexity** — 8 cards × 10 triggers × 6 actions = rich behavior from simple rules.
- **Progressive disclosure** — start with 0 cards (defaults only), unlock editor later.

## Implementation Notes

- Cards stored as flat array, not tree. `evaluate()` is a single loop.
- Each card holds: trigger enum, trigger param (threshold/distance/name), action enum, action param.
- `MAX_CARDS = 8` prevents analysis paralysis and keeps evaluation O(n) trivial.
- Smart defaults per archetype: `default_for_chassis()` returns a pre-built brain.
- Deferred execution: actions like `USE_GADGET` set a `_pending_gadget` flag; the simulation processes it on the next phase. Avoids tight coupling between brain and sim.

## When to Use

Any game AI where:
- Players should be able to customize NPC/unit behavior
- You want emergent behavior without complex authoring tools
- Performance matters (card eval is trivially fast)
- You need different "personalities" per unit type

## When NOT to Use

- Complex multi-step plans (need behavior trees or GOAP)
- Continuous value outputs (need utility AI)
- Reactions to sequences of events (cards are stateless per-tick)
