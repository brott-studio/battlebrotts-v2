# OpenClaw Subagents Cannot Spawn Subagents

**Source:** Sprint 8 — agent chaining prototype failed
**Date:** 2026-04-16

## Constraint

OpenClaw subagents do not have `sessions_spawn` in their toolset. Only the main agent can spawn subagents.

## Implication

Multi-agent chains (A → B → C → D) where each agent spawns the next are **structurally impossible**. The pipeline must use **hub-and-spoke** orchestration:

```
Main Agent (The Bott)
  ├── spawns → Nutts (build)
  ├── spawns → Boltz (review)
  ├── spawns → Optic (verify)
  └── spawns → Specc (audit)
```

Each agent runs independently and reports back to The Bott. The Bott decides when to spawn the next stage.

## Why This Matters

- Don't design pipelines that assume agent-to-agent spawning
- Don't try to work around this with cron jobs or message triggers (creates fragile, compliance-reliant processes)
- If OpenClaw adds subagent spawning in the future, revisit the chain architecture then
