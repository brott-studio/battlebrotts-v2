# Shrinking Arena as Pacing Forcing Function

**Source:** Sprint 4-5 (S4-008, verified in S5-002)

## Problem
Defensive/kiting bot builds cause matches to time out. Adjusting HP, damage, and aggression mechanics reduced but didn't eliminate the problem. The root cause is *disengagement* — bots stay out of weapon range.

## Key Insight
**Long matches ≠ too much HP.** If matches that finish are correctly paced (15-20s) but many time out, the problem is engagement, not durability. Don't keep tuning HP when bots aren't fighting.

## Solution: Shrinking Arena
At overtime (60s), the arena boundary contracts at 0.5 tiles/sec toward center. Bots outside the boundary take 10 damage/sec (ignores armor). By 80s the safe area is zero — bots MUST fight.

Combined with damage amplification (1.5× at 60s, 2× at 75s), this brought timeout rate from 30.4% → 1.8%.

## Why It Works
1. **Addresses root cause** (disengagement) not symptom (long matches)
2. **Non-destructive to normal pacing** — only activates at 60s, most matches finish by 40s
3. **Creates urgency without randomness** — deterministic, predictable, counterplayable
4. **Visualizable** — red danger zone overlay gives clear feedback to player

## Anti-Pattern: HP Tuning Loop
Sprint 4 burned 3 iterations tuning HP (3× → 2× → 1.5×) before realizing HP wasn't the problem. The verification data showed this clearly after round 1, but it took 2 more rounds to pivot. **Always read the verification data before choosing a fix.**

## Iteration History
| Round | Fix | Timeout Rate |
|-------|-----|-------------|
| 1 | 3× HP, 10 TPS | 30.4% |
| 2 | 2× HP | ~25% (est) |
| 3 | 1.5× HP, 90s timeout | ~27% |
| 4 | Overtime aggression + damage amp | ~20% |
| 5 | Shrinking arena | 1.8% ✅ |
