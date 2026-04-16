# KB — Edit-tool Unicode Mismatch Loop

**Discovered:** S13.3 (2026-04-16)
**Severity:** Process / tooling
**Impact:** Pipeline stalls mid-sprint, requires subagent re-spawn.

## Observation

Nutts has now timed out twice when an in-flight edit targets a file
region containing multi-byte unicode characters in adjacent columns —
typically GDD tables or design-doc tables that use:

- em-dash `—` (U+2014)
- multiplication sign `×` (U+00D7)
- arrows `→` (U+2192), `↑/↓`
- non-breaking spaces, narrow no-break spaces
- smart quotes `"` `"` `'` `'`

The failure mode: the edit tool reads the file, the agent proposes a
`oldText`/`newText` replacement that matches at the character level but
the tool's exact-byte matcher sees a normalization or encoding
mismatch, returns "not found", the agent re-reads and re-proposes —
and loops until the subagent wall-clock times out.

## Why it happens

Two plausible causes (either or both):
1. **Normalization drift.** The tool chain reads via one path that
   applies NFC normalization (or strips BOMs / normalizes newlines),
   but writes via a path that doesn't, so round-tripped strings stop
   byte-matching the on-disk file.
2. **Tokenizer vs filesystem mismatch.** The agent is reasoning over
   tokenized text where `—` is one glyph; the tool's matcher is
   byte-exact. A single stray `­` (soft hyphen, U+00AD) or `\u202f`
   (narrow NBSP) in the target region is invisible in the rendered
   diff but blocks the match forever.

## Triggers seen

- S13.2 fix pass: GDD §5.3.1 TCR table (em-dashes in heading row).
- S13.3 PR commit: `docs/design/sprint13.3-chassis-balance.md` tables
  with `×` and `—`.

Both required a subagent re-spawn to complete.

## Mitigations

**For Nutts (and any agent doing file edits):**

1. **When an edit fails twice on the same region**, stop looping. Do
   one of:
   - Fall back to a **full-file rewrite** (`write`) rather than `edit`.
   - **Isolate the change** to a non-unicode-heavy section of the file
     (e.g. append a new subsection rather than modifying a table in
     place).
   - **Pre-normalize** the target file (`uconv -x any-nfc` or a Python
     `unicodedata.normalize('NFC', s)` pass) before attempting the edit.
2. **When authoring GDD/design-doc tables** that will be edited later,
   prefer ASCII equivalents where lossless: `-->` over `→`, `x` over
   `×`, `--` over `—`. Save the pretty glyphs for prose.
3. **When a PR description needs a table**, consider putting the table
   in a separate `.md` file that isn't likely to be edited again, and
   link from the PR body.

## Related

- See also `latent-bugs-inactive-paths.md` for a different failure
  class that also hides in rarely-exercised code paths.
- Mirror of the general principle: tools that agree on *rendered*
  representation may disagree on *byte* representation. Assume they
  disagree and design the recovery path accordingly.
