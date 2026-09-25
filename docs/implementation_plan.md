# Implementation Plan — DI Dynasty Perk Editor: salvage, repair, verification

Status: **executed** (steps 1–7 done, steps 8–9 pending your in-game pass).
Owner: audit of the uncommitted "vanilla-look restyle" work on branch
`Adding-Dynasty-Legacy-Perk-Picking`, taken over after the previous attempt left the
generators unable to produce their own shipped output.

## [Overview]

Restore the Dynasty Perk Editor toolchain to a state where the shipped vanilla-look grid
is reproducible, every artifact is self-consistent, and the drift validator gates
releases — keeping every change that could be verified against the game files and
discarding the scratch-script reassembly that broke the generators.

Context: the cheat itself already worked in-game (free-mode add with exact renown
top-up, right-click remove with zero refund, out-of-order add/remove intended). The
uncommitted work did two genuinely good things — it removed the `enabled =
GetScriptedGui(...).IsValid(...)` bindings that swallowed right-click removal, and it
regenerated `gui/DI_generated_perk_grid.gui` in the vanilla legacy-window look — and it
did them with a clean extraction of the scripted-GUI emit (its output was provably
byte-identical). But the grid emit was then dismantled by one-shot line-index slicing
scripts (`_emit_tmp.ps1`, `_rebuild_tmp.ps1`), producing a `tools/_grid_templates.ps1`
that mixed top-level execution code with function definitions and lost
`Write-VanillaPerkButton` into a stray `tools~_tmp_button.ps1txt`. Net effect: the
generator crashed, the validator crashed, and the 244 KB shipped grid could no longer be
regenerated.

Scope of this plan: the `LRNZ-Divine-Intervention-Base-Menu-Modifications` repo plus the
one-line `descriptor.mod` hygiene change in the AGOT repo. No CK3 script semantics were
touched — `common/scripted_guis/DI_generated_perk_toggles_sgui.txt` and
`common/script_values/DI_generated_perk_values.txt` remain byte-identical. The compatch
generator (`tools/generate_mod_perks.ps1`) keeps its old flat look on purpose: restyling
it depends on the still-unverified `di_perk_grid_extension` override semantics.

## [Per-file verdict]

| Path | Verdict | Why (evidence) |
|---|---|---|
| `gui/DI_generated_perk_grid.gui` | **KEEP** | Produced by the last working tool state; reproduced byte-for-byte by the repaired generator (5617 lines, only the restored placeholder differs); braces balanced; 105 perk buttons == 105 SGUI add blocks; look matches `game/gui/window_dynasty_legacy.gui`. |
| Removal of all `enabled = …IsValid(…)` bindings (grid + 4 in `generate_mod_perks.ps1`) | **KEEP** | That binding tracks the *add* direction, so owning a perk disabled the button and `onrightclick` (remove) could never dispatch. |
| `tools/generate_perk_editor.ps1` SGUI extraction + `-Check` | **KEEP** | Regenerated SGUI/values hash-match the shipped files → provably behavior-preserving. |
| `tools/_grid_templates.ps1` (as found) | **REPLACED** | Top-level emit code ran at dot-source time before `$perks`/`$tracks`/`$utf8Bom` existed; called `Write-VanillaTrackSection` before defining it; called `Write-VanillaPerkButton` which existed nowhere. Now definitions-only. |
| `tools/_check_tmp.ps1`, `_emit_tmp.ps1`, `_rebuild_tmp.ps1`, `tools~_tmp_button.ps1txt` | **DISCARDED** | One-shot file rewriters (hard-coded line ranges) — the cause of the breakage. `Write-VanillaPerkButton` was salvaged from the last one first. |
| Deletion of the empty `di_perk_grid_extension` type | **REVERTED** | Left `gui/DI_dynasty_perk_editor.gui:253` instantiating an undefined type with no compatch enabled, on the back of a self-contradictory load-order claim. |
| `gui/DI_dynasty_perk_editor.gui` (`1400 → 1680`, `+ margin_left = 40`) | **KEPT, flagged** | 1680 px is required by the 296 px buttons; the `margin_left` shift needs an in-game centring check (trivial to revert). |
| `tools/_perk_parser.ps1`: `Test-PerksModel` | **KEPT + wired in** | Guard existed but had zero callers; the generator now aborts before writing if the parsed model is inconsistent. |
| `tools/_perk_parser.ps1`: `Get-TrackOrder` | **DISCARDED** | Alias over `Group-PerksByTrack`, no consumers. |
| `tools/generate_mod_perks.ps1`: skip `DI Perks *` in `Get-ModCandidates` | **KEPT** | `-SubMod 'Hiraeth'` was resolving to the generated compatch instead of the source mod. |
| UTF-8 BOM on the two `generate_*.ps1` | **DISCARDED** | Repo convention for `.ps1` is no BOM; pure diff noise (generated *game* files keep their BOM, which CK3 wants). |
| `tools/validate_perk_editor.ps1` | **KEPT + FIXED** | Right idea, and it is what exposed the breakage. Fixed: phantom `-CheckOnly` usage line, `Out-Null` hiding generator crashes, hard-coded `GameDir` (now `$env:CK3_GAME_DIR`), explicit "generator is broken, not drifting" case. |
| `docs/DYNASTY_PERK_EDITOR_AUDIT.md` | **KEPT + CORRECTED** | Load-order claims marked UNVERIFIED; false "validator passes" claim removed. |
| `docs/implementation_plan.md` (as found) | **REWRITTEN** (this file) | Sections shuffled; promised artifacts that never existed (`DI_generated_perk_data.txt`, `generate_mod_perks.ps1 -CheckOnly`, duplicate-slug guard). |
| `ck3-tiger.conf` | **KEEP** | 287 B tool config (`languages.check = "english"`). |
| `.ck3modding/tiger-baseline.json` | **IGNORED** (not committed) | 1.25 MB, 1763 findings with baked-in absolute paths, stamped *before* the rework → machine-bound and stale. |
| *(AGOT repo)* `descriptor.mod` minus `path=` | **KEEP** | Shipped descriptor must not carry an absolute local path; `mod/LRNZ-Divine-Intervention-AGOT-modifications.mod` supplies it. |
| `mod/DI Perks - HAGOT` / `- A Game of Thrones` / `- Hiraeth …` | **OUT OF SCOPE** | Regenerated 09-01 23:22: already carry the `enabled=` fix, still old flat look, still the sole `di_perk_grid_extension` redefiners. |

## [Types]

- `di_generated_perk_grid` (vbox, generated) — vanilla-look body: 21 track sections, 105 perk buttons at `296 128`, 14 `HasDlcFeature` gates, **0** `enabled=` bindings.
- `type di_perk_grid_extension = vbox { layoutpolicy_horizontal = expanding }` — **restored** as the base's empty placeholder inside `types DI_DynastyGeneratedPerks`, because `gui/DI_dynasty_perk_editor.gui:253` instantiates it and the accepted "one compatch per modlist" design (`DYNASTY_PERK_EDITOR_PLAN.md`, *Coexistence*) depends on the shared name.
- `DI_DynastyGeneratedSubmod<prefix>` / `DI_DynastyGeneratedCombined<prefix>` — unchanged, compatch generators only.
- **Not created (descoped):** `common/script_values/DI_generated_perk_data.txt` — no consumer needs it; the SGUI and values already emit from one parsed model.
- **Rejected, do not re-add:** `DI_grant_dynasty_perk_<key>` macro (scripted effects take no parameters), `DI_track_remove_down_*` / prerequisite guards (out-of-order is intended), `Get-TrackOrder` (zero-consumer alias).

## [Files]

**Repaired**
- `tools/_grid_templates.ps1` — rebuilt as a **definitions-only** module: `Write-VanillaPerkButton` (salvaged from the discarded `tools~_tmp_button.ps1txt`) + `Write-VanillaTrackSection`. No top-level statements: the owner script keeps the `StringBuilder`, `$tracks`, the encoding and the file write.
- `tools/generate_perk_editor.ps1` — `_grid_templates.ps1` dot-source moved to after `$utf8Bom`; `Test-PerksModel` guard after parsing; the dangling comment tail replaced by the real "Generate GUI grid" emit (header comment + `types DI_DynastyGeneratedPerks {` + track loop + the restored placeholder + write + "Done."); output dirs now created for the SGUI and grid writes too (was values-only), so regeneration into a fresh `-ModDir` works; BOM stripped.
- `tools/validate_perk_editor.ps1` — see verdict table; also reports missing generator output as a broken generator.
- `tools/_perk_parser.ps1` — `Get-TrackOrder` removed, `Test-PerksModel` comment corrected, trailing newline added.
- `tools/generate_mod_perks.ps1` — BOM stripped; logic untouched (the two kept fixes stay).
- `.gitignore` — added `.ck3modding/`.

**Deleted:** `tools/_check_tmp.ps1`, `tools/_emit_tmp.ps1`, `tools/_rebuild_tmp.ps1`, `tools~_tmp_button.ps1txt`.

**Regenerated:** `gui/DI_generated_perk_grid.gui` (+3 lines: the placeholder). `common/scripted_guis/DI_generated_perk_toggles_sgui.txt` and `common/script_values/DI_generated_perk_values.txt` unchanged (hash-verified).

## [Functions]

| Function | File | Change |
|---|---|---|
| `Write-VanillaPerkButton($Sb, [string]$Key, [string]$Track)` | `tools/_grid_templates.ps1` | Restored (salvaged); emits the always-enabled 296×128 perk button. |
| `Write-VanillaTrackSection($Sb, [string]$Track, $PerkList, [string]$Gate)` | `tools/_grid_templates.ps1` | Kept, now defined in a module that runs no code. |
| `Write-PerPerkBlocks` / `Write-TrackAddAllBlock` / `Write-TrackRemoveAllBlock` | `tools/generate_perk_editor.ps1` | Kept as-is; must keep producing byte-identical SGUI. |
| `Test-PerksModel($PerkMap)` | `tools/_perk_parser.ps1` | Now called by the generator; aborts before any write. |
| `Get-TrackOrder` | `tools/_perk_parser.ps1` | **Removed** (use `Group-PerksByTrack`). |
| `Get-ModCandidates` | `tools/generate_mod_perks.ps1` | Kept working-tree change: skips `DI Perks *` compatch entries. |

## [Classes]

N/A — no PowerShell classes, no CK3 widget classes added or removed.

## [Dependencies]

No packages. Runtime requirements: PowerShell 7 (`pwsh`), a CK3 install for `-GameDir`
(default `H:\SteamLibrary\steamapps\common\Crusader Kings III\game`, or set
`$env:CK3_GAME_DIR`), optional Paradox Modding Toolkit (`ck3-tiger`) whose baseline stays
ignored. No `.mod` / `descriptor.mod` changes in the base repo.

## [Testing]

All commands run from the repo root.

| # | Check | Result |
|---|---|---|
| 1 | `[Parser]::ParseFile` on all `tools/*.ps1` | **PASS** — 0 errors, 0 BOMs |
| 2 | `pwsh -NoProfile -File tools/generate_perk_editor.ps1 -Check` | **PASS** — parses first, then `Done. 105 toggles, 21 track rows generated.` (before repair: `Done. 0 toggles …` *before* parsing, then crash) |
| 3 | Regenerate into a temp `-ModDir`, hash-compare | **PASS** — `toggles` + `values` **IDENTICAL**; `grid` differs only by the 3 restored placeholder lines |
| 4 | `pwsh -NoProfile -File tools/validate_perk_editor.ps1` | **PASS** — `VALIDATION PASSED`, exit 0 (before repair: crash at `_grid_templates.ps1:35`, exit 1) |
| 5 | Grid invariants | **PASS** — 126 `button_standard`, 105× `296 128`, 21 sections, 14 `HasDlcFeature`, 0 `enabled =`, `di_perk_grid_extension` defined 1× / instantiated 1×, 1620 `{` == 1620 `}`, 105 unique perk keys == 105 SGUI add blocks |
| 6 | **In-game matrix — YOU RUN THIS** | free-mode add renown delta 0 · remove delta 0 · out-of-order add/remove both succeed · right-click on an **owned** perk removes it (the point of the `enabled=` removal) · DLC-present vs absent row visibility · window `1680` + `margin_left = 40` centring (revert the margin if off-centre) · `error.log` free of `pdx_gui_widget`, undefined-type and `Inconsistent effect scopes` entries |
| 7 | **Compatch probe (after 6 is green)** | enable base + `DI Perks - HAGOT`: do the compatch rows render? This settles whether a modded definition of `di_perk_grid_extension` wins over the base's placeholder. If it does **not** render, fall back to the mechanism the base repo already uses for vanilla windows: ship a same-path full-file override of `gui/DI_generated_perk_grid.gui` from the compatch and drop the shared slot (and its instantiation) entirely |

## [Implementation Order]

1. Done — rebuild `tools/_grid_templates.ps1` as a definitions-only module (salvage `Write-VanillaPerkButton`).
2. Done — fix `tools/generate_perk_editor.ps1`: dot-source placement, `Test-PerksModel` guard, real grid emit with the restored placeholder, output-dir creation, BOM strip.
3. Done — regenerate all three artifacts; tests 2–5 green; `common/` diff-clean.
4. Done — delete the scratch scripts; strip the BOM from `generate_mod_perks.ps1`; remove `Get-TrackOrder`; ignore `.ck3modding/`.
5. Done — repair `tools/validate_perk_editor.ps1` (test 4 green).
6. Done — rewrite this document; correct `docs/DYNASTY_PERK_EDITOR_AUDIT.md`; note in `docs/DYNASTY_PERK_EDITOR_PLAN.md`.
7. Pending — commit the base repo in two commits: `fix: restore working perk-editor generator + extension slot`, then `chore: drop perk-editor scratch scripts, add drift validator, ignore ck3modding baseline`.
8. Pending — commit the AGOT repo: `chore: keep local path out of descriptor.mod (launcher .mod file carries it)`.
9. Pending — in-game pass (test 6), then decide on `margin_left = 40`.
10. Pending — compatch probe (test 7); only then restyle `tools/generate_mod_perks.ps1` onto the shared grid templates.

## [Known limitations]

- Shipped generated files stay **patch-locked**: a new DLC track means re-run the generator, re-validate, re-release.
- The compatch look (`mod/DI Perks - *`) is still the flat 260×44 style until step 10.
- `ck3-tiger` has not been re-run since the restyle; the stale baseline was deliberately not committed, so run the lint locally and judge the findings fresh.
- Owned-perk state is still not renderable (`has_dynasty_perk` is a script trigger, not a GUI datafunction), which is why buttons are intentionally always enabled.



