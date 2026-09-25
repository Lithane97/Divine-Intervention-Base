.


# Alphabetical compact perk grid

Base and the SubMod compatch generator sort track sections A–Z using the final
merged English `<track>_name` localization. Comparison is case-insensitive English,
with an ordinal internal-key tie-breaker. Static `$key$` references are resolved
with cycle/depth protection; unresolved or runtime-dependent names fall back to
the track key. This is generation-time ordering, not runtime language-aware sorting.

Only the GUI's selected track list is sorted. Perks within each track, source-mod
precedence, scripted effects, bulk-operation order and tooltip localization retain
their existing order/content. Manifest `trackKeys` records actual display order;
the full `availableTracks` catalog retains source order for diagnostic selection.

Individual perk buttons are 296 × 64, with label top margin 8. Track headings,
track icons, track action buttons, font size, 24-pixel checkmarks, ownership
bindings and click actions are unchanged.

## Verification and rollout

`tools/test_grid_layout.ps1` checks sorting fixtures. Its optional `-BeforeGrid`,
`-AfterGrid` and `-ManifestPath` arguments compare each real track section and
reject any content changes beyond button height and label margin. The existing
validator also runs the sorting fixtures and ownership-expression checks.

This layout is staged under `.ck3modding/alphabetical-compact/`, separately from
the previous `.ck3modding/crash-isolation/` variants. Original installed full
grids are preserved in `pre-existing/`; the pre-layout running session snapshot
is under `sessions/`. Generated effects and localization must match installed
files byte-for-byte, and repeat generation must produce identical manifests/hashes.

Exit CK3 before installation. Install only each staged `gui/DI_generated_perk_grid.gui`
into its owning Base or AGOT 45-Mod compatch. Do not copy staging descriptors or
alter the playset. Verify installed hashes against the staged manifests.

On the next launch, check alphabetical headings, long-label readability, checkmark
placement, scrolling and left/right click actions. Observe stability separately;
the layout update does not establish that the earlier whole-PC restart is fixed.

## Staging verification (2026-09-07)

- 105 Base cells / 21 tracks and 1,277 compatch cells / 262 tracks verified.
- Every track section matches its original byte-for-byte after substituting only
  height 128 → 64 and label margin 18 → 8; wrapper content is unchanged.
- Effects and localization match the installed files byte-for-byte. Repeated
  Base and compatch generation produced identical grid manifests/hashes.
- Generator validation, sorting fixtures and ownership-expression tests pass.
- Tiger 1.19.0, targeting detected CK3 1.19.0.6: the staged Base overlay has zero
  reports with the installed Base loaded as parent. The compatch retains the same
  40 existing reports (17 errors, 23 warnings) under its AGOT/Bloodlines/Base/DI AGOT
  parent context; no added diagnostics. This is not a claim that all of Base is
  error-free.
- Installation and visual gameplay checks wait until the current CK3 session exits.
