# Dynasty Perk Editor crash isolation

The confirmed defect is N-ary `And` in track-header ownership expressions. The
generator now emits binary expressions. The machine freeze remains unproven.
Generation and static validation do not establish runtime stability.

## Generate staged variants

Run from the Base repository in PowerShell 7:

```powershell
./tools/prepare_grid_diagnostics.ps1
```

This uses the SubMod route with AGOT then Bloodlines in engine order. It creates
`.ck3modding/crash-isolation/agot-full`, `agot-empty`, `agot-1-tracks`,
`agot-5-tracks`, `agot-20-tracks`, `agot-50-tracks`, `agot-1-tracks-owned-off`,
and `agot-full-owned-off`. It does not install variants or modify the launcher.
It checks identical effects/localization/dependencies across variants, repeat
generation, expression arity, counts, and launcher-descriptor preservation.

Both generators support `-DiagnosticEmptyGrid`, `-DiagnosticGridTracks <keys>`
and `-DiagnosticDisableOwnedState`. Supply `-ModDir` for Base or `-TargetFolder`
for SubMod. Diagnostics require a staging subdirectory of TEMP or this repository's
`.ck3modding`; they cannot target installed mod roots. Empty-grid and track-list
options are mutually exclusive and unknown keys fail. Selection preserves source
order internally; newly generated grids display the selected tracks alphabetically
by English heading, with perk order within each track unchanged. Older staged
crash-test artifacts are retained as generated. Pass multiple keys as a PowerShell array when invoking
the script from PowerShell; do not rely on native-shell comma splitting.

`DI_grid_manifest.json` records ordered source paths, selected keys, cell and
binding counts, SHA-256, and the complete track catalog with DLC gates. The first
probe uses the first ungated five-perk track. Full variants retain all tracks.
The input model, effects, localization, and bulk-operation coverage never change.
Explicit SubMod output folders no longer register a launcher descriptor.

## Apply and test one variant

Close CK3 before swapping files. Preserve the installed compatch grid first. Copy
**only** the chosen variant's `gui/DI_generated_perk_grid.gui` to the same path in
`../DI Perks - AGOT 45-Mod Playset/`. Do not copy staged descriptors, change the
playset, remove Bloodlines, or load two compatches. Compare its SHA-256 with the
manifest before testing. Keep `agot-full` for restoring the corrected full grid.

The user launches CK3. Use the same save, dynasty, playset, DLC and settings:

1. Empty grid: open, close, reopen, select a foreign dynasty and switch back.
   Do not click bulk actions; their full effects deliberately remain present.
2. One track: repeat opening and switch free mode off/on. Do not grant perks yet.
3. Advance through 5, 20, 50, then all tracks only while each stage is responsive.
4. If a grid fails, archive the evidence before considering the exact same track
   set with `-DiagnosticDisableOwnedState`. The prepared one-track/full comparisons
   are not substitutes for the same-set comparison at 5, 20, or 50 tracks.

After each session, archive before another launch overwrites logs:

```powershell
./tools/archive_grid_test.ps1 `
  -VariantDirectory ./.ck3modding/crash-isolation/agot-empty `
  -Outcome 'responsive' -Notes 'Same save; opened twice; switched dynasty'
```

The archive contains logs, active mod/DLC list, UTC metadata, relevant recent
Windows events when readable, variant metadata, and the actual installed grid
hash. A mismatch invalidates attribution. CK3 log timestamps are retained rather
than incorrectly assumed to be UTC. Event 41 alone does not identify the cause.
After a whole-machine freeze, stop launches, inspect the evidence, and obtain
the user's authorization before another test.

## Branches and completion

- Empty grid fails: investigate the shell. Independently validate selected
  dynasty state; preserve valid foreign selections, repair from a valid selected
  character or the player, and refuse opening if neither supplies a dynasty.
  Implement/test that only on this branch. Test animation removal separately.
- One track fails: compare identical content without ownership bindings before
  increasing size; inspect that track's data and selected-dynasty context.
- Only larger grids fail: record scale sensitivity. Reduced grids are diagnostic,
  not permission to permanently remove perks. Specify a renderer redesign from
  evidence; visibility gating alone is not proof of reduced engine work.
- Full grid works: test owned-state refresh, player/foreign editing, free/paid
  grants and removals, track/bulk operations, exact renown outcomes, and save/load.
  Restore full normal output for delivery unless a diagnostic is explicitly kept.

No refund changes, tooltip sanitization, source-mod exclusion, or speculative
pagination is part of this patch. The existing single-execution open/close code
is preserved. A passing static check is not a successful gameplay test.

## Implementation verification (2026-09-07)

- Base and AGOT/Bloodlines normal outputs preserve all effects and tooltip files
  byte-for-byte against the pre-change installation. Only 42 Base and 524 compatch
  header expression lines changed in their installed grids; full content remains.
- Staged compatch variants contain 0, 5, 25, 100, 250, and 1,277 cells. The first
  track is `forrester_legacy_track_BLA`. Ownership-disabled comparison variants
  retain click actions and emit zero ownership bindings.
- Independent binary-arity/truth-table tests, generation drift validation,
  deterministic compatch generation, and staging rejection checks passed.
- Tiger 1.19.0 detected CK3 1.19.0.6. Base reports fell from 1,804 to 1,762;
  compatch reports fell from 564 to 40 with AGOT, Bloodlines, Base and DI AGOT
  parent context. Exactly 566 N-ary `And` warnings disappeared, with no new
  reports. Existing errors remain: 19 in Base and 17 in the compatch.
- Backups, manifests, generation logs and before/after Tiger reports are under
  `.ck3modding/crash-isolation/`. The archive helper passed a synthetic fixture.
- No CK3 launches or gameplay tests were performed. Empty-grid testing is the
  next runtime step. Conditional shell/selection repairs are not implemented
  because that branch has not been reached.
