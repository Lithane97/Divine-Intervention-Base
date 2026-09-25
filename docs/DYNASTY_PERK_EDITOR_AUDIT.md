# DI Dynasty Perk Editor — Audit Findings

Companion to `implementation_plan.md`. Preserves the reasoning and confirmed behaviors so they aren't re-litigated.

## Confirmed / verified against game files (patch 1.19)
- `add_dynasty_perk` / `remove_dynasty_perk` / `has_dynasty_perk` are real dynasty-scope effects/triggers.
- Cost formula: `common/defines/00_defines.txt` = `COST = PERK_COST_BASE(250) + ownedPerks * PERK_COST_MULTIPLIER(500)`.
- Per-track owned-count triggers `<track>_perks` exist natively (seen in `00_legitimacy_values.txt`, `06_ce1_legends_values.txt`, `07_ep3_values.txt`), matching the generated `DI_dynasty_perk_cost_next`.
- Track keys in `common/dynasty_legacies/*.txt` match the perk `legacy = <track>` and the generated count-trigger name. DLC gates are exactly `is_shown = { has_dlc_feature = X }`.
- DLC perk/legacy data loads for everyone, so granting a DLC perk never errors for users without it; `HasDlcFeature` hiding is cosmetic parity.

## Intended behavior (confirmed by user — do not "fix")
- **Out-of-order add/remove is intended.** No prerequisite/dependency gating, even though vanilla doesn't allow it.
- **Removal refunds zero renown (100% observed).** `remove_dynasty_perk` returns nothing. Only the owned-perk count (hence next cost) changes.
- Free-mode **add** refund (exact cost top-up before grant) stays; it keeps splendor stable. Remove is a no-refund no-op on renown. Add-then-remove leaves the perk free with renown intact — a cheat-intended outcome.

## Architecture verdict
- Build-time enumeration is **engine-forced**: no runtime dynasty-perk iterator, no scripted-effect parameterization, and `DynastyView.SelectPerk` re-validates in C++ (Option A rejected). The per-key generated SGUI is necessary.
- The parser + two-generator split + shared parser is clean. Keep it.

## Risks / gaps (open)
- **UI nit (RESOLVED):** owned-perk state can't be rendered greyed (`has_dynasty_perk` is a script trigger, not a GUI datafunction). The `enabled = ...IsValid` binding was removed entirely so buttons are **always enabled**: left-click = add (no-op if already owned via the add SGUI's is_shown guard), right-click = remove (no-op if not owned). Right-click removal now always dispatches and out-of-order add/remove stays intended. Same change applied to the per-track add-all button so right-click remove-all also always fires.
- **Maintenance:** shipped generated files are patch-locked; new DLC tracks require regeneration + release.
- **Mod compatch:** `di_perk_grid_extension` is a name-keyed type shared between the base mod (empty placeholder) and one compatch (the real rows) → exactly ONE DI Perks compatch per modlist; regenerate a combined compatch to show several. Filenames are per-mod-unique (name slug), so no filename collision; the shared slot is the intentional "collision." **UNVERIFIED:** which definition of the shared type name actually wins across load order. Both answers were claimed in this document at different times ("last-loads-wins" here, "first-wins" in the restyle update below) and neither was tested — see "Open experiment" at the end.
- **Workshop:** current generator emits **local** mods (`path=`, name-based `dependencies`, hardcoded `supported_version="1.19.*"`). Not directly uploadable. Publishing is an optional follow-up; if done, publish **combined** items and emit `steamId`-based deps.

## Update — compatch parity + regeneration (post in-game test)
- **Fixed** `generate_mod_perks.ps1` to match the vanilla always-enabled fix: removed the 4 `enabled=...IsValid` bindings in `New-DiSubMod` (299, 312) and `New-DiCombinedMod` (488, 501). Compatch buttons are now always enabled (left=add, right=remove).
- **Fixed** `-SubMod`/combined source resolution: `Get-ModCandidates` registry loop now skips `DI Perks *` compatch entries (matching the existing local dir-scan skip), so `-SubMod 'Hiraeth'` resolves to the workshop source, not the generated compatch.
- **Regenerated** the Hiraeth compatch (16 rows / 45 buttons), the AGOT compatch (17 rows / 53 buttons), and a combined `DI Perks - HAGOT` (33 rows / 98 buttons, deduped 45+53). All have **0** `enabled=` bindings; combined manifest lists both sources.
- **SUPERSEDED (2026-09-02):** the proposed fallback there — "remove the base's empty `di_perk_grid_extension` definition" — was tried in the uncommitted restyle and has been **reverted**: with no base definition, `gui/DI_dynasty_perk_editor.gui` instantiates an undefined widget type whenever no compatch is enabled, which is a certain break traded for an untested engine assumption. The placeholder is generated again. The render question is now a deliberate experiment ("Open experiment" below) instead of a guess.

## Update — vanilla-look grid restyle (implemented)
- `tools/generate_perk_editor.ps1` emits a **vanilla-legacy-window look** for the vanilla grid: each track is a vanilla-style section (80×80 track icon via `gfx/interface/icons/dynasty/<track>.dds` + localized `_name`/`_desc` header) followed by a `flowcontainer` of **per-key** perk buttons (296×128, `mask_frame_horizontal.dds` ×2 layers + `tile_frame_thin_02`, `[Localize('<key>_name')]`), each wired to its own `DI_perk_add_<key>`/`remove_<key>`.
- `gui/DI_generated_perk_grid.gui` regenerated (105 styled perk buttons, 21 track headers, 0 `enabled=` bindings, 14 `HasDlcFeature` gates).
- **Not mirrored:** `tools/generate_mod_perks.ps1` (Hiraeth / AGOT / combined) still emits the old flat 260×44 style; restyle it only after the in-game check and the extension-slot experiment below.
- Window `DI_dynasty_perk_editor` widened `1400 → 1680` px so four 296 px buttons fit per row; `margin_left = 40` added — **not yet eyeballed in game**, revert the margin alone if the window sits off-centre.

## Update — toolchain salvage & repair (2026-09-02)
The restyle was landed by one-shot scratch scripts that sliced the generator by line index and left it broken; the tools could no longer reproduce their own shipped output (`pwsh tools/generate_perk_editor.ps1` died at `_grid_templates.ps1:35`, `-Check` exited 0 while silently not regenerating the grid).
- `tools/_grid_templates.ps1` rebuilt as **definitions only** (it used to run top-level emit code while being dot-sourced *before* `$perks`/`$tracks`/`$utf8Bom` existed, and called `Write-VanillaPerkButton`, which was defined nowhere — its body survived only in a stray `tools~_tmp_button.ps1txt`).
- Grid emit moved back into `tools/generate_perk_editor.ps1` after the parse + encoding setup; `Test-PerksModel` now actually runs; output dirs are created for all three artifacts.
- Proof of a clean repair: regenerating into a temp dir reproduces `DI_generated_perk_toggles_sgui.txt` and `DI_generated_perk_values.txt` **byte-identically** (hash match) and the grid **line-for-line** except the restored placeholder. `tools/validate_perk_editor.ps1` passes (it previously crashed).
- Discarded as junk: `tools/_check_tmp.ps1`, `tools/_emit_tmp.ps1`, `tools/_rebuild_tmp.ps1`, `tools~_tmp_button.ps1txt`, `Get-TrackOrder`, the `.ps1` BOMs. The 1.25 MB `.ck3modding/tiger-baseline.json` is now ignored rather than committed (absolute local paths, stamped before the restyle).
- Full per-file keep/discard reasoning: `docs/implementation_plan.md`.

## Open experiment — who wins a shared GUI type name?
Setup: base mod defines an empty `di_perk_grid_extension`; one compatch redefines the same type with real rows and declares a dependency on the base (so it loads after).
Observation to record: do the compatch rows render, and does the *base* vanilla grid still render?
- Rows render → mod-loaded-later wins → keep this design and restyle the compatch generator onto the shared templates.
- Rows do not render → the shared-name slot is unusable → do **not** re-delete the base placeholder; instead move to a same-path full-file override (`gui/DI_generated_perk_grid.gui` shipped by the compatch, the mechanism this mod already relies on for vanilla windows) and drop both the slot and its instantiation in `DI_dynasty_perk_editor.gui`.

## Rejected designs (kept out)
- Safe-remove / dependency-order guards.
- `DI_track_remove_down_*` helper.
- Generic toggle collapsed to a parameterized scripted effect (not possible in CK3).
- Runtime dynamic enumeration.
- Shipping the base mod without a `di_perk_grid_extension` definition (undefined type in `DI_dynasty_perk_editor.gui` whenever no compatch is active).
- Regenerating files with ad-hoc line-index splice scripts instead of editing the generator.
