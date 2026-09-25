# Dynasty Perk Editor — Action Plan

> The concrete "what to do next" plan, based on research into the installed game files
> (patch 1.19, `H:\SteamLibrary\...`). `DYNASTY_PERK_EDITOR_OPTIONS.md` is the superseded
> research doc (Option B rejected); `DYNASTY_PERK_EDITOR_AUDIT.md` tracks per-file state.

> **v2 (audit-refined).** Changes vs v1:
> - **Generator-first:** the PowerShell generator (old Phase 3a) is now *Phase 1 step 0* — do
>   not hand-write per-track effects. The grid is per-perk toggles (105 vanilla perks), which
>   makes hand-writing infeasible and the generator non-optional.
> - **Per-perk toggles, not "add next":** the stated goal is *any perk, any time* — so each
>   perk gets its own toggle (add if missing, remove if owned), replacing the sequential
>   `else_if` chain design.
> - **Scope bug fixed in the example:** `add_dynasty_prestige` is a *dynasty-scope* effect
>   (effects.log) — the v1 example placed it in character scope where it would error. It also
>   must run *before* the grant, or the purchase can still fail.
> - **Shipping model decided:** base mod = vanilla tracks only; each perk-mod gets its own
>   sub-mod (AGOT pattern). See "Phase 3 — Shipping modded-track variants".
> - `add_dynasty_perk` renown deduction downgraded from "confirmed" to "likely — verify in the
>   first test" (if script grants bypass costs like the console command, refund logic can be
>   dropped entirely).

> **v3 (2026-08-31).** Test 1 result + generator split:
> - **Option A Test 1 FAILED as predicted:** the gated vanilla-window override enabled every
>   perk button, but `DynastyView.SelectPerk` re-validates prerequisites/renown internally in
>   C++ — clicks were silently ignored. The override was removed; the scripted per-perk toggle
>   grid is the editor (Phase 1 implemented, commits `a6c543f`/`bc18b87`).
> - **Generator split into two tools** (user decision): one for vanilla+DLC perks (shipped in
>   the base mod), one for scanning the user's installed mods / playsets (Phase 3, spec below).
> - Phase 3 rewritten as a full spec with UX flow, output modes, and playset integration —
>   **spec is a draft; user will add more specifications later.**

> **v4 (2026-08-31 audit).** Implementation audit findings:
> - **FIXED — scope bug in generated toggles:** the free-mode `add_dynasty_prestige` top-up
>   was emitted at root *character* scope, but the effect is dynasty-scope only. `error.log`
>   confirmed `Inconsistent effect scopes (character vs. dynasty)` for **every generated
>   toggle** (~110 load errors). Generator template fixed (top-up moved inside
>   `var:DI_dynasty_selected_dynasty`, gated via `root = { has_variable = ... }`) and files
>   regenerated. **Action: relaunch once and confirm these errors are gone from error.log.**
> - **DLC trees ARE handled correctly** (the main worry — verdict: fine):
>   - All DLC legacy/perk definitions live in `game/common/` and load for **everyone**
>     regardless of ownership — perk keys are always defined, so `has_dynasty_perk` /
>     `add_dynasty_perk` on DLC perks **never errors** for users without the DLC. The
>     `HasDlcFeature(...)` row-hiding is cosmetic parity with vanilla, not error prevention.
>   - Vanilla gates tracks exactly the way the generator does: `is_shown = { has_dlc_feature
>     = X }` in `common/dynasty_legacies/*.txt` (verified in all 10 DLC files), and vanilla GUI
>     itself uses `HasDlcFeature('...')` (verified in `frontend_bookmarks.gui`). The
>     generator's gate parsing matches vanilla's own pattern — this is the idiomatic approach.
>   - Gate→track attribution verified correct, including the edge cases: single-line
>     `is_shown` blocks (99_legacies.txt), the commented-out gate in 97_ep1_legacies.txt
>     (correctly ignored), and 94_ce1_legacies.txt having two differently-gated tracks
>     (`ce1_heroic_track` → `legends`, `ce1_legitimacy_legacy_track` → `legends_of_the_dead`).
>   - Note: `HasDlcFeature`/script `has_dlc_feature` check the **host's** DLC — irrelevant in
>     single player, correct behavior in multiplayer.
>   - Design choice to consider: hidden DLC rows mean a user without Northern Lords *can't*
>     cheat in pillage perks, even though the script would allow it (keys defined). Optional:
>     a "show DLC-gated tracks" window toggle. Your call — vanilla parity is the safer default.
> - **Appendix track table was wrong** (real keys differ, 21 tracks not 20) — see corrected
>   note in the appendix. The generator reading real files is exactly why this doesn't matter.
> - Minor: generator log line referenced `$tracks` before it was built — fixed.

> **v5 (2026-09-01, in-game test results).**
> - **`add_dynasty_perk` renown deduction CONFIRMED in-game** (cost varies per perk, matching
>   `250 + 500 × total owned`). The flat +2750 top-up was replaced by an **exact pre-grant
>   refund** via generated script value `DI_dynasty_perk_cost_next`
>   (`common/script_values/DI_generated_perk_values.txt`): 250 base + 500 per owned perk using
>   the auto-generated `<track>_legacy_track_perks` triggers. Net renown change ≈ 0 → **no
>   splendor level inflation** (splendor tracks current prestige, per the user's own earlier
>   observation that re-adding prestige pushes the level back up).
> - **Buttons now vanilla-styled** (`DI_ce_present_dark_button` family): track icon
>   (`gfx/interface/icons/dynasty/<track>.dds` — verified to exist in vanilla), localized perk
>   names via `<perk_key>_name` loc keys, track headers via `<track>_name`/`<track>_desc`.
>   Note: perks have **no** `_desc` loc keys (vanilla builds perk tooltips in C++); button
>   tooltips fall back to the perk name for now. `fp3_persianate_legacy_track.dds` is an
>   orphaned vanilla icon with no track/perk defs — correctly ignored by the generator.
> - **Layout overlap fixed:** the grid was in a floating overlay widget (`margin_top = 150`)
>   over the header/selector; scrollbox moved into the main vbox flow. Also fixed earlier:
>   inverted free-mode toggle button, free mode now defaults ON at window open (`default`).
> - **Open test item:** does `remove_dynasty_perk` refund renown? If yes, toggling a perk off
>   gains renown — check in-game and compensate if unwanted.

> **v6 (2026-09-01, second in-game test).**
> - **Click semantics split (user requirement):** left click = add, right click = remove,
>   inapplicable direction is a no-op. Perk buttons grey out when owned (the add scripted
>   gui's `is_shown` = `NOT has_dynasty_perk`, surfaced via `GetScriptedGui(...).IsValid` —
>   the mod's standard enabled pattern). This also gives owned-state visual feedback for
>   free, solving the old "can't show owned state" limitation.
> - **Per-track buttons added** (user request): each track header has a "Track" button —
>   left click unlocks all missing perks in the track, right click removes all owned.
>   Effects skip already-in-target-state perks so renown is only touched on real grants.
> - **Loc mystery solved ("only Bureaucrats loaded"):** the AGOT-replace theory was WRONG
>   (user wasn't running AGOT; AGOT's replace file keeps the vanilla keys anyway). Actual
>   cause: **bare loc keys in modded GUI `text =`/`tooltip =` properties don't resolve** —
>   vanilla never does that; its keys are only reached via `$key$` loc links or
>   `GetDynastyPerk(...).GetName` (C++ path). "Bureaucrats" was the single exception because
>   it's the only perk whose name also appears in a `*_modifier` loc key rendered through a
>   working text path elsewhere. **Fix: the generator now emits
>   `[Localize('<perk>_name')]` explicitly** for all button text/tooltips and track headers.
>   Fallback if Localize misbehaves: generate `DI_perk_<key>_name: "$<key>_name$"` loc keys.
>   (Side note: AGOT does ship `localization/replace/english/dynasty_legacies/legacies_l_english.yml`
>   which wholesale replaces vanilla's base legacy loc when AGOT IS loaded — keep in mind
>   for the AGOT sub-mod; it renamed `blood_legacy_5_name` → "Old Kings".)
> - **Splendor note (SUPERSEDED by v6.1):** there is NO `set_dynasty_prestige` effect
>   (checked effects.log) — only `add_dynasty_prestige`. ~~splendor tracks current prestige~~
>   WRONG, corrected in v6.1: splendor tracks **lifetime earned** prestige.
> - Tooltip limitation stands: perks have no `_desc` loc keys (C++-built tooltips), button
>   tooltip = perk name. Perk *effect* text could be added later via custom loc calling
>   `GetDynastyPerk('<key>').GetEffectDescription` if desired.
> - **CRASH FIX (same day):** `flowcontainer` rejects `hbox`/`vbox` roots as direct children
>   (`pdx_gui_container.cpp:142`, crash on map load). `DI_ce_present_dark_button` is an hbox →
>   added `DI_ce_present_dark_widget_button` (identical but widget-rooted) in
>   `DI_char_editor_templates.gui`; the generator now uses it for perk buttons.
> - **v6.1 (same day, test 3):**
>   - Perk buttons unclickable → the `enabled=` greying inside the button was disabling its
>     own hit area; fixed by putting `button_ignore = none` on the widget wrapper.
>   - Free mode default → widget `default=` never fired; moved to the window's `_show`/`_hide`
>     state `on_start` (ON at open, OFF at close), which is the reliable lifecycle hook.
>   - **Splendor CONFIRMED to track lifetime earned prestige, not current balance:** user
>     observed level increasing with renown flat at -6133. Net-zero refund keeps the
>     *balance* flat but splendor still climbs (+cost then -cost = lifetime gain). There is
>     no `set_dynasty_prestige` and no splendor-agnostic grant — a truly splendor-neutral
>     free mode is impossible via script; the editor's free mode is therefore defined as
>     **renown-cost-free, not splendor-free**. Noted in the cheat-mode tooltip.
> - **v6.2 (same day, test 4):**
>   - **Template+blockoverride buttons abandoned.** The `DI_ce_present_dark_*_button` family
>     lost right-clicks and clicks entirely (button_standard_clean + blockoverride appears to
>     mishandle input). Perk buttons switched to the mod's proven pattern — plain
>     `button_standard` with inline icon+text content, `onclick`/`onrightclick`/`enabled`
>     directly on the button (as in the skills tab / title manager). `DI_ce_present_dark_
>     widget_button` kept in the templates file but no longer used by the generator.
>   - Top controls consolidated into one fixed-size row after the header (free-mode toggle
>     210px + splendor label/−1/+1/reset) — the previous expanding rows spread buttons across
>     the full window width.
>   - Reminder: GUI changes need a game restart; testing without one shows stale UI.

> **v7 (2026-09-01, end-of-day status)**
>
> **✅ Working (user-confirmed in-game):**
> - Per-perk buttons: left click adds, right click removes, owned perks grey out
>   (`enabled` = add sgui's `is_shown` via `IsValid`)
> - Track buttons: left click unlocks whole track, right click locks whole track
> - Perk/track names and icons render (via explicit `[Localize('<key>_name')]`)
> - Cross-dynasty selection (char picker → `DI_dynasty_selected_dynasty`) works
> - Free mode: renown stays flat (exact pre-grant refund), defaults ON at window open,
>   OFF at close (state `on_start` hooks), toggleable mid-session
> - Splendor editor row: +1/−1/Reset-to-0 via `add_dynasty_prestige_level`
> - Window scrolls; all 21 tracks reachable
>
> **⚠️ Known limitations (by design / unfixable via script):**
> - Splendor level creeps up in free mode even with exact refunds — it tracks *lifetime
>   earned* prestige and `LEVEL_DROP_MAX_RETAINED_PROGRESS_PRESTIGE = 0.5` makes drops
>   asymmetric. No script fix exists (no `set_dynasty_prestige`); the splendor row is the
>   user-side correction. Vanilla's own scripted precedent (Mongol event) is *sloppier*
>   (brute-force +10000 renown + 5 levels).
> - Perk tooltips = perk name only. **v8: effect tooltips confirmed IMPOSSIBLE** — the only
>   effect-text API is `DynastyPerk.GetEffectDescription(GetPlayer)` (vanilla cooltip.gui),
>   which requires a DynastyPerk *datacontext*. That context comes only from engine-bound
>   datamodels (`DynastyView.GetLegacies` / `DynastyLegacy.GetPerks`), and there is no
>   `GetDynastyPerk(key)` global lookup, no Dynasty→Legacy promotion, and no `_desc` loc keys
>   (effect text is C++-built). The earlier "custom loc" idea is dead. Perk-name tooltips stay.
> - Owned state = greyed button only; no per-perk tooltip count/checkmark.
>
> **❓ Not yet re-tested after latest changes (restart pending at time of writing):**
> - Window sizing: static `size = { 1400 90% }` (v6.2 rework, commit `83ce133` — an earlier
>   draft of this list said "50% width"; superseded before any restart test)
> - Controls consolidated top-left; header shows selected dynasty's name via loc key
>   `DI_dynasty_perks_editor_heading` = `"[Dynasty.GetNameNoTooltip|U] Dynasty — Legacy
>   Perk Editor"`
> - Dead `dynasty_legacies_container` overlay widget removed (it caused the original
>   overlap bugs)
>
> **📋 Next steps, in priority order:**
> 1. **Restart + regression pass:** verify the v7 layout (1400×90% static-width window,
>    control bar, dynasty name in header) and re-confirm clicks/track buttons still work
>    after the layout rework.
>    Also answer the last open test-matrix item: does `remove_dynasty_perk` refund renown?
>    (If yes, toggling off gains renown → add a compensating deduction.)
> 2. **Out-of-order grant check** (plan test matrix item #1): click a tier-3 perk with 0
>    owned — confirm scripted grants ignore track order (expected) or handle if not.
> 3. **Trait-selection perk check** (item #2): `blood_legacy_4` (Architected Ancestry) —
>    scripted grant behavior unknown (default trait / nothing extra / error).
> 4. **Phase 2 polish:** localization pass for other languages (only english has the new
>    keys); silence the `DI_dynasty_selected_*_copy` "set but never used" warnings (comment
>    out setters in `DI_dynasty_selected_char_copy` until the copy feature is built); the
>    explanation text loc (`DYNASTY_VIEW_SHOW_LEGACY_EXPLANATION_*`) hardcodes the *player's*
>    dynasty — consider a DI-owned loc with the selected dynasty's name.
> 5. **Phase 3:** the Mod Support Generator (`tools/generate_mod_perks.ps1`) — spec below
>    reviewed and hardened in v9; nothing implemented yet, extension-slot step 1 first.
> 6. **Workshop readiness:** the `is_shown`-driven greying means the editor needs no
>    compat patches for vanilla; sub-mods only needed for modded tracks (Phase 3).

> **v9 (2026-09-01, plan review — status audit + Phase 3 spec hardening — CURRENT STATE)**
>
> Full audit of the codebase vs. this plan (git log, generator, window GUI, sgui, loc):
>
> | Phase | State | Evidence |
> |---|---|---|
> | 0 — baseline cleanup | ✅ done | commit `e01f44d` |
> | 1 — generated toggle editor | ✅ done, in-game verified (tests 1–4) | commits `a6c543f`, `bc18b87`, `ba80240`; `tools/generate_perk_editor.ps1` (388 lines) → `DI_generated_perk_toggles_sgui.txt` / `DI_generated_perk_grid.gui` / `DI_generated_perk_values.txt` |
> | 2 — polish | ✅ essentially done | free-mode lifecycle (`_show`/`_hide` `on_start`), splendor +1/−1/reset row, copy-setters silenced, explanation paragraph replaced, loc keys in `gui/DI_l_english.yml`. Remaining: other-language loc (low prio — game falls back to english); "Dynasty to Copy" parked by design |
> | 3 — Mod Support Generator | ✅ done (v12+) | `tools/generate_mod_perks.ps1` (F1 scanner, F3 standalone, F4 playset/combined compatches, F2 menu), auto-launcher registration, and `docs/ADDING_PERK_MOD_SUPPORT.md` guide are implemented; the editor window instantiates `di_generated_perk_grid` **and** the `di_perk_grid_extension` compatch slot |
>
> The v7 regression items above remain the first field action (restart still pending):
> 1400×90% layout, `remove_dynasty_perk` refund behavior, out-of-order grant, trait-perk.
>
> Phase 3 spec hardened per this review — all additions marked **[v9]** inline below:
> base-DI descriptor dependency, per-sub-mod cost script value, duplicate-key exclusion,
> standalone-mode multi-select guard, `mods_registry.json`/launcher DB as primary mod
> source, multi-library Steam fallback, parser hardening (single-line perk blocks,
> zero-perk warnings), literal shared parser, corrected playset-JSON wording in the
> implementation order, and a Phase 3 test checklist.

> **v13 (2026-09-02, uncommitted-restyle salvage — CURRENT STATE).** The vanilla-look grid
> restyle and the always-enabled button fix are kept, but the tooling that produced them had
> been dismantled by one-shot line-index splice scripts: `tools/_grid_templates.ps1` ran
> top-level emit code at dot-source time (before `$perks`/`$tracks`/`$utf8Bom` existed) and
> called `Write-VanillaPerkButton`, which existed only in a stray scratch file — so
> `generate_perk_editor.ps1` crashed and could not reproduce the shipped grid.
> - Generator rebuilt: `_grid_templates.ps1` is definitions-only, the grid emit lives in
>   `generate_perk_editor.ps1` after the parse, `Test-PerksModel` guards the model, and all
>   three writes create their output dir. Verified: `toggles` + `values` regenerate
>   **byte-identical**, grid regenerates **line-for-line**, validator passes.
> - **The empty `type di_perk_grid_extension` placeholder in the base grid is restored.**
>   The restyle had deleted it on a "first-wins" claim that contradicts this plan's own
>   "last-loads-wins" note and left `DI_dynasty_perk_editor.gui` instantiating an undefined
>   type with no compatch active. The override semantics stay an open experiment — see
>   `docs/DYNASTY_PERK_EDITOR_AUDIT.md` ("Open experiment") before restyling the compatch
>   generator onto these shared templates.
> - Scratch tooling deleted; `.ck3modding/` (1.25 MB machine-bound tiger baseline) is now
>   ignored; `tools/validate_perk_editor.ps1` is the release gate. Per-file
>   keep/discard/repair reasoning: `docs/implementation_plan.md`.

> **v14 (2026-09-03, three-track implementation review — CURRENT STATE).** Independent
> review of GUI, effects/tooling, and docs (subagent-assisted; drift validator re-run,
> PASSED — 105 perks / 21 tracks, deterministic byte-identical output). Findings consolidated:
>
> **Blockers:**
> - `gui/DI_dynasty_perk_editor.gui:271-488` — dead ~220-line `types DI_DynastyLegacies`
>   block (vanilla `hbox_legacy_item` copy, zero instantiations, missing datacontext).
>   (done, this changeset).
> - Non-free mode grants renown-free perks: the generated toggles only top up renown when
>   free mode is ON, but never verify the dynasty can afford the perk when OFF. Fix in the
>   generator (`Write-PerPerkBlocks` / `Write-TrackAddAllBlock` in
>   `tools/generate_perk_editor.ps1`), then regenerate. Do NOT add a
>   "selected dynasty = root's dynasty" guard — editing foreign dynasties is the editor's
>   purpose. (done, this changeset.)
>
> **Should fix:**
> - `DI_dynasty_splendor_reset` (`DI_dynasty_perk_editor_sgui.txt` ~line 121) hardcodes
>   `-10`; one click fails to reach splendor level 0 when the level is 10 or higher.
>   (done, this changeset — reset now loops until splendor level 0.)
> - The v9 Phase 3 status row above is stale ("⏳ step 1 done", "generate_mod_perks does
>   not exist") — the full implementation order (F1 scanner, F3 standalone, F4 combined,
>   F2 menu, guide) is complete per v12/v13. This v14 entry supersedes that row.
> - The companion reference to the rejected `OPTIONS.md` was removed from the header
>   (see top of this file).
> - `tools/validate_perk_editor.ps1:69` — brace-balance check runs on grid + toggles only;
>   change `@($files[0], $files[1])` to `$files` so the values file is covered too.
>   (done, this changeset — plus a structural check that the editor window still
>   instantiates both `di_generated_perk_grid` and `di_perk_grid_extension`.)
> - `pinned_for_edit` flag persistence across save/load is unverified
>   (`common/scripted_guis/DI_perk_point_sgui.txt`); if non-persistent, pinned edits
>   silently fall back to root-only after reload.
> - Dead scaffolding: commented "Copy dynasty char" placeholders in
>   `gui/DI_dynasty_perk_editor.gui` (~lines 202-208) and the stub
>   `DI_dynasty_selected_char_copy` sgui; `gui/DI_dynasty_perk_editor_templates/DI_dynasty_perk_editor_templates.gui`
>   is fully commented out; duplicate `name = "perk_point_value"` across 5 widgets in
>   `gui/DI_perk_point.gui`. (done, this changeset.)
>
> **Nice to have:**
> - In-game check of `margin_left = 40` window centering (never eyeballed).
> - `di_perk_grid_extension` compatch load-order experiment still untested (carry-over
>   from v13 / `DYNASTY_PERK_EDITOR_AUDIT.md` "Open experiment").
> - Owned/locked visual state in the grid = accepted engine limitation (`has_dynasty_perk`
>   is script-only); add a header note to the generated grid file.
> - README and `FEATURE_INVENTORY.md` omit the perk editor entirely; typos:
>   "Bad choce" (`tools/generate_mod_perks.ps1:591`), missing space
>   (`docs/ADDING_PERK_MOD_SUPPORT.md:28`). (done, this changeset — both inventories
>   now mention the perk editor; typos fixed; mod-update regeneration note added to
>   the guide.)
>
> **Confirmed healthy (no action):** generator parses 105 perks / 21 tracks dynamically
> from game files (no hardcoded lists); exact global renown formula
> (`250 + 500 × total owned perks`) incl. the TGP alias; per-perk add/remove with
> `is_shown` guards; track add-all/remove-all buttons; clean free-mode lifecycle
> (`_show`/`_hide`); `di_confirmation_popup` defect resolved; no vanilla
> `window_dynasty_legacy.gui` override; historical docs properly banner-marked; drift
> validator passes.

> **v15 (2026-09-04, Hiraeth compatch in-game failure — same-path override rework — CURRENT STATE).**
> In-game test of the Hiraeth compatch failed (heroism row ended in vanilla "Down in History"
> instead of Hiraeth's "Once More Unto the Breach"; compatch grid never rendered). Root causes
> verified from `gui_warnings.log` / `error.log` (session 2026-09-03 22:55) and file inspection:
>
> **1. First-loaded-wins confirmed (closes the v13/v14 "open experiment"):**
> `gui_warnings.log` — `Type 'di_perk_grid_extension' already registered at
> 'gui/DI_generated_perk_grid.gui'(5615)`. CK3 silently rejects re-registered GUI types;
> the base mod's empty slot definition always won, so the compatch's 1393-line extension grid
> was never instantiated. The extension-slot mechanism is dead; the base mod's slot definition
> and window instantiation stay (harmless back-compat), but compatches must not define the type.
>
> **2. Same-path full-file override (implemented in `tools/generate_mod_perks.ps1`, -SubMod):**
> the compatch now emits its grid at exactly `gui/DI_generated_perk_grid.gui` (base mod's path),
> as a COMPLETE grid computed from [mod dynasty_perks dir, surviving vanilla files] merged by
> perk key (first-seen-wins per key; mod same-name files replace whole vanilla files per CK3's
> file-override rule). Hiraeth regenerated: 150 perks / 21 tracks (45 new keys); stale
> extension-slot grid deleted from the compatch folder. Load order: compatch AFTER base mod
> (descriptor dependency ensures this).
>
> **3. Hiraeth reassignment root cause (the "Down in History" mismatch):** Hiraeth REPLACES
> vanilla `common/dynasty_perks/05_ce1_dynasty_perks.txt` and reassigns vanilla key
> `ce1_heroic_legacy_5` to `ce1_legitimacy_legacy_track` (as an `always = no` stub, loc left
> vanilla = "Down in History"); the real new 5th heroism perk is `hth_ce1_heroic_legacy_5`
> ("Once More Unto the Breach"). The merged grid now shows `hth_ce1_heroic_legacy_5` in the
> heroism row and `ce1_heroic_legacy_5` in the legitimacy row — verified by `rg` in the
> regenerated grid.
>
> **4. `margin_left` confirmed invalid (error.log):** `Property 'margin_left'(814) not handled`
> on `DI_dynasty_perk_editor_window` — the v14 "verify in game" item is resolved: removed from
> `gui/DI_dynasty_perk_editor.gui` (parallel changeset, recorded here for completeness).
>
> **5. Tooltip loc files added (both generators, in-game verification pending):** grid buttons
> now reference `DI_perk_tt_<perk>` loc entries (bold name + effect `text =` keys, excluding
> `*_ai_effect`/`*_req_effect`) emitted to `localization/english/DI_generated_perk_tt_*.yml`.
> Mirrors vanilla's highlight tooltip structure.
>
> **6. Affordability guard mirrored in the mod generator:** `-SubMod` and combined toggles now
> grant inside the free-mode branch, else `else_if = { dynasty_prestige >= <per-submod cost
> value> }` — matching the base generator's v14 fix (independent template code).
>
> **Verification:** ck3-tiger 1.19.0 on the regenerated Hiraeth compatch — fatal 0; 593
> errors are all `missing-item` for `hth_*` perks / `hth_legacy_track` (expected: compatch
> checked alone, Hiraeth's files not in scope); zero reports about the grid types; the
> doubled-quote `default_format = ""#high""` bug is gone (no such output emitted). Static
> checks: 150 grid buttons / 150 toggle pairs / 21 track rows / 150 tooltip entries / braces
> balanced in grid + toggles / cost value covers all 21 merged tracks. In-game verification
> pending (grid render, tooltips, renown deduction, splendor).

---

## 🎉 Key research findings (new — verified in vanilla files)

### 1. The grant effect EXISTS: `add_dynasty_perk`

Found in `common/scripted_effects/00_mongol_invasion_effects.txt` — vanilla itself uses it to
grant legacies to the Mongol empire:

```paradox
dynasty = {
    add_dynasty_prestige_level = 5
    add_dynasty_prestige = 10000
    add_dynasty_perk = warfare_legacy_1
    add_dynasty_perk = warfare_legacy_2
    ...
}
```

- Works inside a `dynasty` scope → we can target the selected dynasty. **Scope access fix:** the
  selection is stored as a *player-scope variable* (set via `scope:target.set_variable`), so the
  correct script access is `scope:player.var:DI_dynasty_selected_dynasty` (or `var:DI_...` when
  already inside the player scope) — **not** `scope:DI_dynasty_selected_dynasty` (that syntax is
  for `save_scope_as` saved scopes, which this is not).
- ⚠️ **COST WARNING (likely — verify in first test):** `add_dynasty_perk` probably **deducts
  renown** from the dynasty. Confirm with exact before/after renown numbers in the very first
  Phase 1 test — if the script effect turns out to bypass costs (the way the
  `gain_all_dynasty_perks` console command does), the whole refund/top-up design below can be
  dropped.
  Evidence:
  - `DYNASTY_PRESTIGE_COST_LONG` loc = `"Renown: [dynasty_prestige_i] $VALUE|0$"` — dynasty
    prestige **is** renown.
  - Cost formula from defines: `COST = PERK_COST_BASE (250) + unlocked_perks * PERK_COST_MULTIPLIER (500)`
    → perks cost 250 / 750 / 1250 / 1750 / 2250 (total 6,250 for a full track).
  - The Mongol event grants `add_dynasty_prestige = 10000` **alongside** its 5+ perks — consistent
    with the script effect charging renown and the event compensating for it.
  - In-game memory confirms: granting a perk consumes the required renown; re-adding prestige
    afterwards pushes the renown *level* back up.
- **Mitigation for the editor:** after each `add_dynasty_perk`, compensate with
  `add_dynasty_prestige = <cost>` (compute from the perk's index: `250 + 500 * index`), or simpler:
  add a fixed large refund (e.g. `add_dynasty_prestige = 2500` per perk) or a separate
  "Renown +5000" cheat button. Exact per-perk refund is cleaner:
  ```paradox
  add_dynasty_perk = warfare_legacy_1
  add_dynasty_prestige = 250      # refund perk 1 cost
  ```
- Symmetric trigger `has_dynasty_perk = <key>` exists (used in `varangian_events.txt`,
  `artifact_events.txt`) → we can guard "add next perk" per track.

### 2. Perk definitions are data-driven and enumerable on disk

- Perks: `common/dynasty_perks/*.txt` — **105 perks** in vanilla (10 DLC files)
- Naming convention is 100% consistent: `<track_prefix>_legacy_<1..5>` (e.g. `warfare_legacy_1`,
  `fp1_adventure_legacy_3`)
- Each perk declares its track: `legacy = warfare_legacy_track`
- Tracks: `common/dynasty_legacies/*.txt` — **20 tracks** in vanilla (9 base + 11 DLC)

### 3. No script-side iteration exists

No `every_dynasty_perk` / `any_dynasty_perk` anywhere in vanilla. Script **cannot enumerate** the
perk list at runtime. GUI-side, only `DynastyView.GetLegacies` (engine-bound, see options doc).

### ➜ Consequence: **Option B (dynamic enumeration) is not possible in script.**
**Option C (hardcoded grid) + the discovered `add_dynasty_perk` effect is the way** — and it can
still cover modded legacies via a small compatibility pattern (see Phase 3).

---

## ✅ Script docs generated (in-game `script_docs` console command) — findings

Logs are in `Documents/Paradox Interactive/Crusader Kings III/logs/`:
`effects.log`, `triggers.log`, `event_scopes.log`, `event_targets.log`.

### Confirmed effects (both dynasty scope)
| Effect | Signature |
|---|---|
| `add_dynasty_perk` | `add_dynasty_perk = key` — adds perk (deducts renown) |
| `remove_dynasty_perk` | `remove_dynasty_perk = key` — **removal IS possible!** Phase 2 remove-buttons are go |

### Confirmed triggers (dynasty scope)
| Trigger | Signature |
|---|---|
| `has_dynasty_perk` | `has_dynasty_perk = key` |
| `<track>_legacy_track_perks` | **auto-generated per track** (20 vanilla ones found) — compares perk count: `warfare_legacy_track_perks >= 3`. **Mods adding tracks get their own trigger automatically** → tooltips/progress display can be dynamic per track! |

### Still missing
- No `every_/any_dynasty_perk` iterator → runtime enumeration remains impossible →
  Phase 3a generator still required for modded track coverage.
- No dynasty→perk scope links in `event_targets.log`.

---

## Phase 0 — Clean the test baseline (do before any Option A testing)

The current WIP has real parser errors that would contaminate any Option A test results
(unrelated `gui_warnings.log` noise). Fix or remove:

- [ ] `gui/DI_dynasty_perk_editor.gui:219` — invalid `GetAllDynasties.GetLegacies` datamodel
      (GetAllDynasties has no GetLegacies). Remove or replace with a working source.
- [ ] `gui/DI_dynasty_perk_editor.gui:236` — invalid top-level `di_confirmation_popup`
      (confirmation popups must be declared inside a window/`confirmation_popup` context).
- [ ] `gui/DI_dynasty_perk_editor.gui:6-8` — three competing root `datacontext` declarations;
      only the last wins. Keep one (the `Var('DI_dynasty_selected_dynasty').Dynasty` one) and
      delete the rest.
- [ ] `gui/DI_misc.gui` copy selector calls `DI_dynasty_select_char_copy` but the defined
      scripted gui is `DI_dynasty_selected_char_copy` — rename one to match (or defer the whole
      copy feature; it's not needed for MVP).
- [ ] Delete dead code: `DI_Dynastey_perk_list` in
      `common/scripted_guis/DI_dynasty_perk_editor_sgui.txt` — this is worse than dead code:
      undefined `scope:legacy` **and** an `if` with no `limit`, i.e. a hard parser error that
      spams `error.log` on every load. Also delete the empty `if = { limit = {...} }` in
      `DI_dynasty_selected_char_copy` and the commented `DI_dynasty_perk_helper`.
- [ ] After cleanup: launch once and confirm `error.log` / `gui_warnings.log` are free of
      dynasty-editor-related entries. That is the clean baseline.

---

## Phase 1 — Core editor: generated per-perk toggles for vanilla tracks (MVP)

**Goal:** Working per-perk toggle buttons (add/remove) for all 105 vanilla perks across the
20 vanilla tracks — all files **generated**, not hand-written.

### 1.0 Write the generator FIRST (do not hand-write effects)

With per-perk toggles (below), the editor needs **one effect + one button per perk** — 105 in
vanilla, more with mods. Hand-writing that guarantees typos. Write
`tools/generate_perk_effects.ps1` (not shipped with the mod) first; it:

1. Scans `H:\SteamLibrary\...\game\common\dynasty_perks\*.txt` (vanilla) — later, any perk
   mod's folder too (Phase 3).
2. Extracts every perk key + its `legacy = <track>` association (+ track order for layout).
3. Emits:
   - `common/scripted_effects/DI_dynasty_perk_effects.txt` — one toggle effect per perk
   - `gui/DI_dynasty_perk_editor_templates/DI_dynasty_perk_grid.gui` — the button grid,
     grouped by track, using the mod's existing button template styling
   - `localization/english/DI_dynasty_perks_l_english.yml` — tooltip loc referencing vanilla
     perk loc keys where possible (perk names/descs already exist in vanilla loc — reuse their
     keys instead of duplicating text)

Then every game/mod-list change is a re-run, not a rewrite.

### 1.1 Per-perk toggle effects (generated, not hand-written)

**Design change (v2):** per-perk toggles instead of per-track "add next perk" `else_if`
chains. Rationale: the stated goal is *any perk, any time, no prerequisites* — a sequential
chain contradicts that. Each perk gets one toggle effect:

```paradox
DI_dynasty_toggle_warfare_perk_1 = {
    scope = character
    effect = {
        # root is the player (SetRoot(GetPlayer.MakeScope) from GUI);
        # the selected dynasty lives in the player's variable storage
        scope:player = {
            var:DI_dynasty_selected_dynasty = {
                if = {
                    limit = { has_dynasty_perk = warfare_legacy_1 }
                    remove_dynasty_perk = warfare_legacy_1
                }
                else = {
                    # free-edit mode: top up renown FIRST, and INSIDE dynasty scope —
                    # add_dynasty_prestige is dynasty-scope only (effects.log), and granting
                    # after the purchase attempt would be too late
                    add_dynasty_prestige = 3000
                    add_dynasty_perk = warfare_legacy_1
                }
            }
        }
    }
}
```

**v1 example bugs this fixes:** the old example put `add_dynasty_prestige` in character scope
(would error — dynasty-scope effect per effects.log) and ran it *after* the grant attempt
(too late if renown was insufficient).

**Renown cost — corrected model (audit finding):** the cost formula is
`250 + TOTAL unlocked dynasty perks × 500` — based on the dynasty's **total** perk count across
all tracks, **not** the perk's position within its own track. Per-track refunds (250/750/…)
are therefore wrong once the dynasty owns perks elsewhere. Options:

- **"Free edit" mode (default):** flat top-up before each grant (as above). Note this inflates
  renown *level* progress — unavoidable, level derives from total prestige gained.
- **"Normal cost" mode:** no top-up; pair with a separate "Renown +5000" button.
  Make the mode a `GetVariableSystem` toggle in the editor window; the generated effect reads
  it via a scripted trigger if both modes are wanted, or just ship free-edit only for MVP.

> If precise cost-neutral granting is ever wanted, the refund must be computed from the dynasty's
> **total** owned perk count (`250 + total_perks × 500`) *before* the grant — countable via the
> auto-generated `<track>_legacy_track_perks` triggers summed across all tracks. Defer unless
> requested; the flat-grant cheat mode is simpler and fits the cheat intent.

**Unknowns to resolve in the first test session (the Phase 1 test matrix):**

1. Does scripted `add_dynasty_perk` allow **out-of-order** grants (perk 3 with 0 owned)?
   If the engine enforces track order even in script, the toggle UI must either grey out
   later perks or fall back to sequential chains. *Decides the final grid design.*
2. **Trait-selection perks** (blood track "Architected Ancestry"-style): does scripted grant
   apply a default trait, grant nothing extra, or error? Handle per findings.
3. Does `remove_dynasty_perk` tolerate removing a perk while later perks in the track are
   owned? (For a cheat tool, arbitrary perk sets are desirable.)
4. Record exact renown before/after — settles the cost question at the top of this doc.

**Bonus from script_docs:** the auto-generated `<track>_legacy_track_perks` triggers (e.g.
`warfare_legacy_track_perks >= 3`) let tooltips show the current perk count per track — and since
these triggers are auto-generated for *every* track (including mod-added ones), any modded tracks
added by the generator automatically get working count tooltips too.

### 1.2 Build the UI (generated grid)
In `gui/DI_dynasty_perk_editor.gui`, replace the placeholder content with the generated grid
(from 1.0) — copy the styling of the lifestyle present buttons (`DI_ce_present_dark_button`
template):

- One button per **perk** (5 per track row): left-click = toggle (add/remove via the 1.1
  effect). Show owned state by stacking two complementary-visibility widgets driven by a
  scripted_gui whose `is_shown` checks
  `scope:player = { var:DI_dynasty_selected_dynasty = { has_dynasty_perk = <key> } }` —
  the mod's existing scripted-gui pattern.
- Track row header: static `texture = gfx/interface/icons/dynasty_legacies/...` per track
  (`DynastyLegacy.GetTrackIcon` won't work without DynastyView).
- Track header tooltip shows current unlocked count via the auto-generated
  `<track>_legacy_track_perks` triggers — dynamic per track, works for modded tracks too.

### 1.3 Wire up
- Register effects as scripted_guis if buttons use `GetScriptedGui(...).Execute(...)` (the mod's
  standard), or call them as scripted_effects from existing guis.
- Test in-game per the unknowns list in 1.1 (out-of-order grant, trait-selection perks, removal
  with later perks owned, exact renown delta), then: select a character → open editor → toggle
  perks → verify in the vanilla dynasty window.

**Deliverable:** generator + functional editor for all vanilla tracks. ~3-4 hours including
the generator and the test matrix (more than v1's 1-2h estimate because the generator is now
front-loaded — it pays for itself the moment modded tracks or regenerations are needed).

---

## Phase 2 — Polish

- [ ] "Dynasty to Copy" feature: buttons per track that copy the *copy-dynasty's* perk count:
      ```paradox
      # pseudo: for each perk 1..5, if copy-dynasty has it and target doesn't → add
      ```
      Needs the `_copy` variables you already built.
- [ ] Renown display already works (`Dynasty.GetPrestige`) — optionally add a
      `add_dynasty_prestige = 5000` cheat button next to the grid.
- [ ] ~~Remove-last-perk~~ — **superseded** by the v2 per-perk toggle design (each perk
      button adds if missing, removes if owned via `remove_dynasty_perk`, confirmed in
      effects.log).
- [ ] Localization for all buttons/tooltips (follow `DI_l_english.yml` conventions).
- [ ] Clean up dead code (see cleanup list in DYNASTY_PERK_EDITOR_OPTIONS.md).

---

## Phase 3 — Shipping modded-track variants (sub-mod pattern)

> **⚠️ v3: This phase is now specified as the "Mod Support Generator" below. The original
> sub-mod rationale (why not bundle everything) still applies and is kept at the end of this
> phase. The spec is a DRAFT — the user will add more specifications later.**

### Phase 3 spec — Mod Support Generator (`tools/generate_mod_perks.ps1`)

> **Status: DRAFT — user will add more specifications. Do not implement until the spec is
> marked final.**

A **second, separate generator** (distinct from the vanilla+DLC generator
`tools/generate_perk_editor.ps1`, which stays as-is and ships in the base mod). Its job:
scan the user's installed CK3 mods, find every mod that adds dynasty perks/tracks, and
generate editor support for them. UX flow and features, in user's words + structure
(order not final):

#### F1 — Scan installed mods for perk content

- Scan all mod locations: `mod/` folder (local mods), Steam Workshop content
  (`steamapps/workshop/content/1158310/<id>/`), and any additional user-specified dirs.
- A mod "adds perks" if it contains `common/dynasty_perks/*.txt` with valid perk blocks
  (reuse the vanilla generator's parser).
- Present results as a list: mod name (from descriptor.mod), workshop ID / path, number of
  perks and tracks found, DLC-gate status of its tracks.
- Handle name resolution: workshop IDs → names via `mod/ugc_*.mod` descriptor files in the
  user folder (the launcher writes these).
- **[v9] Primary mod source: the launcher's own registry.** `mods_registry.json` in the CK3
  user folder (launcher-maintained: name, dirPath, steamId, status) and the `mods` table of
  `launcher-v2.sqlite` already map workshop IDs → names/paths — read them first instead of
  raw directory globbing; keep the `mod/` + Workshop directory scan (with `ugc_*.mod`
  parsing) as the fallback.
- **[v9] Steam multi-library awareness:** Workshop content may live under any Steam library
  (this machine: `H:\SteamLibrary\...`). Resolve library roots via
  `<SteamRoot>/steamapps/libraryfolders.vdf` instead of assuming the default install path.
- **[v9] Parser hardening for arbitrary mods:** the vanilla generator's perk regex only
  matches `key = {` with the opening brace at end of line — single-line perk blocks
  (`my_perk = { legacy = x }`), which mod authors do write, would be silently dropped.
  Support single-line blocks, and warn when a `dynasty_perks/*.txt` file parses to 0 perks
  (probably a parse miss, not an empty file).

#### F2 — User selection: generate for all or a subset

- Interactive menu (or CLI flags for power users): generate for **all detected perk mods**,
  or pick **one/some** via multi-select.
- Show what will be generated before writing (dry-run summary: mods → tracks → perk counts).
- **[v9] Standalone-mode multi-select guard:** every standalone sub-mod defines
  `di_perk_grid_extension` — two of them enabled together = last-loads-wins, one silently
  vanishes. If the user selects more than one perk mod for standalone output, warn and
  recommend the combined playset mode (F4) instead.

#### F3 — Output modes (user chooses per run)

1. **Add to main mod** — write generated files into the base DI mod folder.
   - ⚠️ Caveat to surface in the UI: Steam Workshop updates of the base mod would overwrite
     local changes; users who install the base mod from GitHub are unaffected. (The base mod
     is distributed via GitHub, so this mode is mainly for the maintainer's own install.)
2. **Generate separate standalone mods** (preferred default) — one small mod per perk mod,
   each containing only its generated files (`common/scripted_guis/`, grid `.gui`, loc stubs,
   descriptor with `dependencies = { "<Perk Mod Name>" }`).
   - Each can be independently enabled/disabled in the launcher/playset.
   - Auto-register each generated mod in `mod/` with a `.mod` descriptor so the launcher
     sees it (name pattern: `DI Perks - <Mod Name>`).
   - **[v9] Descriptors must ALSO depend on the base DI mod** (`"<Base DI Mod Name>"`):
     the sub-mod's rows render into the base window's `di_perk_grid_extension` slot, and
     its effects rely on the base's free-mode variable/loc conventions. A dependency on the
     perk mod alone would allow loading without the base mod → grid rows with no slot to
     render into.
3. **Write to a target folder** — emit the generated files into an arbitrary directory so
   they can be dropped into an existing compatch mod by hand.

#### F4 — Playset integration (if feasible)

- Read **Paradox launcher playsets**: `playsets_backup/` and the launcher's own
  `launcher-v2.sqlite` / `game_data.json` in the CK3 user folder (format to be verified —
  research needed; the launcher stores playsets in a SQLite DB, mods per playset in a
  join table).
- Read **Irony Mod Manager playsets**: Irony stores playsets in its own data directory
  (`%APPDATA%/IronyModManager` or similar — format to be verified).
- Let the user pick a playset → the generator scans exactly the mods enabled in that
  playset → generates **one combined mod** containing the editor support for all perk mods
  in that playset (single enable/disable, no per-mod clutter).
- If a playset format can't be parsed reliably, fall back to F2 manual selection.

#### F5 — Shared requirements (inherited from the vanilla generator)

- Same parser, same toggle-effect template, same DLC-gating logic, same free-mode flag.
- Unique type/file naming per generated mod (`-Prefix` derived from the perk mod name) to
  avoid `di_generated_perk_grid`-style collisions when several generated mods are active.
- Idempotent regeneration; "GENERATED FILE" headers; re-run after perk-mod updates.
- **[v9] Duplicate-perk-key exclusion:** exclude every perk key already present in the
  vanilla scan from the generated toggles. A mod that *replaces* vanilla perk files (same
  filename in `common/dynasty_perks/`) or redefines existing keys would otherwise yield
  duplicate buttons next to the base grid's vanilla rows. Mods that only *append* new keys
  (the normal case) are unaffected.
- **[v9] Cost value must cover modded tracks:** the base's `DI_dynasty_perk_cost_next`
  counts only the 21 vanilla tracks, so free-mode refunds under-count once modded perks are
  owned (cost = 250 + 500 × TOTAL owned perks). Each generated mod emits its own
  uniquely-named script value `DI_dynasty_perk_cost_next_<prefix>` computed over
  **vanilla + its modded** tracks, and its toggle effects reference that name — no name
  collision with the base value. The sub-mod generator therefore needs two scan scopes:
  *emit toggles for* = the perk mod's new keys only; *compute cost over* = vanilla + modded
  (the auto-generated `<track>_legacy_track_perks` triggers exist for vanilla tracks no
  matter which tool emits the value).
- **[v9] Make "same parser" literal:** extract the perk/track-gate parser functions into
  `tools/_perk_parser.ps1`, dot-sourced by both generators — one parser fix fixes both.

#### Open questions — RESOLVED (v8 research, 2026-09-01)

- [x] **Playset formats (v8 CORRECTED — verified against the live launcher DB):**
  - `playsets_backup/*.json` is **stale/incomplete** (all empty except one; bulk-copied
    2026-08-30) — NOT the live data. User confirmed.
  - **Live source: `launcher-v2.sqlite` in the CK3 user folder** (SQLite format 3). Schema:
    - `playsets(id, name, isActive, isRemoved, ...)`
    - `mods(id, steamId, displayName, dirPath, status, source, ...)`
    - `playsets_mods(playsetId, modId, enabled, position)` — join table, FK to both
  - **Read path proven on this machine** via Python 3.14 `sqlite3` (stdlib — no extra
    installs): 14 live playsets enumerated, per-playset mod lists joined with names and
    enabled flags. Example: `IronyModManager` playset → 1 mod (the DI test mod, enabled).
  - Generator read strategy: copy the DB to temp (avoids locking the live DB), open with
    Python `sqlite3` (or a bundled reader if Python is absent), join the three tables,
    filter `isRemoved = 0`.
  - Irony Mod Manager: not installed on this machine; if present elsewhere, its JSON
    exports are accepted via `-PlaysetFile <path>` (same shape as the backup JSONs).
- [x] **Window inclusion mechanism — DECIDED (extension-slot pattern):**
  - CK3 types/templates are **global across load order, name-keyed, last-loads-wins**.
  - The base window keeps instantiating `di_generated_perk_grid` (vanilla rows, from the
    vanilla generator). The base ALSO defines `di_perk_grid_extension` — an **empty vbox
    type** — and instantiates it right below the vanilla grid.
  - Standalone sub-mods / combined playset mods **redefine `di_perk_grid_extension`** with
    their rows. Base behavior unchanged when absent (empty slot renders nothing); with a
    sub-mod enabled, its rows appear after the vanilla ones. No base-mod edit needed per
    sub-mod; N slots not needed — one extension type suffices (only one mod can win the
    name anyway, which is exactly the combined-mod model).
  - Verified: types need no `scripted_widgets` registration; any loaded gui file's types
    are global. AGOT parser test passed: **158 perks / 38 tracks** (105 vanilla + 53 AGOT).
- [x] **Naming:** standalone sub-mods get prefix from the source mod
  (`DI_perk_add_agot_*`, type `di_perk_grid_extension` — shared name is intentional and
  IS the inclusion mechanism). Combined playset mods emit the full extension grid in one file.
- [x] **Descriptor dependencies (v9-amended):** standalone sub-mods declare
  `dependencies = { "<Perk Mod Name>" "<Base DI Mod Name>" }` (launcher orders after both —
  the perk mod for its content, the base DI mod for the extension slot + conventions).
  Combined playset mods declare dependencies on all source perk mods present in the playset
  **plus the base DI mod**.
- [x] **UI:** interactive terminal menu (numbered lists, y/n prompts) with CLI flags as
  escape hatch — no WinForms; keeps the tool dependency-free PowerShell.

> **Status (v9): spec reviewed and hardened — ready for implementation.** User additions
> still welcome; implement incrementally in the order below.

### Coexistence — DECISION: one compatch per modlist (v12, 2026-09-01)

**Problem:** two standalone sub-mods both redefine `di_perk_grid_extension` (types global,
name-keyed, **last-loads-wins**) → the later one silently replaces the earlier one's rows.
Confirmed on generated code (Hiraeth + AGOT): perks, tracks, type-names, effect-sgui are all
unique — the only collision is the one shared slot name. Cannot merge at runtime (no
script-side GUI include).

**Decision (v12): the N-slot / Option-A scheme is SCRAPPED.** The editor GUI holds exactly
**one** compatch slot. Therefore:

- **Only one DI Perks compatch may be active in a modlist at once.** Enabling two → the later
  one wins the slot, the earlier one's rows vanish (last-loads-wins).
- **This is by design, not a bug.** Perk *data* and cheat *effects* still work for any number
  of perk mods simultaneously (the engine merges them); it is only the *editor window grid*
  that is single-slot.
- **If you need several perk mods shown together → generate once for that list** using **F4
  combined mode**. The tool's whole purpose is that regeneration. Collect the mods you want,
  run the generator, enable the single combined compatch.

**So the model is:**
```
modlist ──► pick the perk mods you want ──► F4 combined compatch (one mod) ──► enable it
```
Changing the modlist = run the tool again. There is deliberately no N-slot mechanism and no
way to stack independent compatches in one list.

**Duplicate buttons (was v11):** since only one compatch can be active, the "A+B double-include"
duplicate case cannot arise. A combined compatch dedups its NEW keys across the selected set in
one pass, so no duplicates are generated either. No guard needed.

**Manifest (kept, v11→v12):** the combined (F4) compatch ships a manifest listing each
included perk mod (display names + per-mod perk/track counts + prefix) so players know exactly
what's inside before enabling.
  lists (see Step 4).

### Implementation order (v9; supersedes the v8 wording)

> **Status (v10): step 1 implemented (2026-09-01).** The `di_perk_grid_extension`
> slot now exists: the vanilla generator (`generate_perk_editor.ps1`) emits it in
> `gui/DI_generated_perk_grid.gui`, and `gui/DI_dynasty_perk_editor.gui` instantiates
> it below the vanilla grid. **Step 2 (F1 scanner) also implemented (same day):**
> `tools/generate_mod_perks.ps1 -Scan` enumerates perk mods from `mods_registry.json`
> (primary) + dir-scan fallback via the shared parser `tools/_perk_parser.ps1`
> (extracted from the vanilla generator — both dot-source it). Steps 3–6 remain
> not started. Step 1 was the hard prerequisite for any generated rows to render.

1. **Extension slot in base mod** — ✅ **done**. add empty `di_perk_grid_extension` type +
   instantiation below the vanilla grid in `DI_dynasty_perk_editor.gui`; vanilla generator
   (`generate_perk_editor.ps1`) emits it. Verify: restart with no sub-mod → nothing renders,
   error.log clean. *(Files regenerated: `DI_generated_perk_grid.gui` balanced, 927/927.)*
2. **F1 scanner** — ✅ **done** (`generate_mod_perks.ps1 -Scan`). Reads `mods_registry.json`
   first, dir-scan fallback; reports per-mod perk/track/DLC-gate counts via the shared parser.
   Tested: 16 perk mods found incl. Hiraeth (130/17), AGOT (128/32), PoD, Elder Kings 2, LotR.
   Duplicate-key finding: **Hiraeth = 85 vanilla-overlap + 45 new (`hth_*`)** — exclusion is
   mandatory for its compatch (65% of keys would otherwise duplicate the base grid).
3. **F3 standalone mode** — ✅ **done** (`-SubMod <name>`). Generates a full compatch
   (scripted guis + `di_perk_grid_extension` grid + per-prefix cost value + descriptor
   with `dependencies = { "<Perk Mod>" "<Base DI Mod>" }`), auto-registers
   `mod/DI Perks - <Name>.mod`. Duplicate-key exclusion: only non-vanilla keys emitted.
   **No loc emitted** — the perk mod provides real names (e.g. Hiraeth's `hth_l_english.yml`);
   emitting stubs would override them. Verified end-to-end: **Hiraeth compatch generated**
   (45 new perks / 16 tracks; 85 vanilla-overlap dropped; grid braces 461/461 balanced).
   *Note: default target = `<UserFolder>/mod/DI Perks - <Name>`*.
4. **F4 playset/combined mode** — ✅ **done** (v12): `-Playset <name>` reads the playset from
   `launcher-v2.sqlite` (via Python on a temp copy) and emits ONE combined compatch (dedup by
   perk-key across the set, one cross-mod cost value, manifest `README_DI_perks.txt`,
   descriptor deps on all source mods + base DI). Also `-PlaysetMods "A;B"` for an explicit
   list. Verified: Hiraeth+AGOT → 98 new perks / 33 tracks, grid 985/985 balanced, manifest
   lists both mods.
5. **F2 interactive menu** — ✅ **done**: no-args runs scan→3 actions→prompts; verified launches
   and quits cleanly.
6. **Community guide** — ✅ **done**: `docs/ADDING_PERK_MOD_SUPPORT.md` (tools, all CLI modes,
   the menu, in-game steps, troubleshooting, file-collision note).

**[v12] Model change note:** the N-slot/Option-A scheme was **scrapped** — only one compatch
per modlist; use F4 combined for multiple perk mods; regenerating is the tool's purpose.

**[v9→v12] Phase 3 test checklist (run per generated output):**
- [ ] No sub-mod enabled → extension slot renders nothing, error.log clean.
- [ ] AGOT sub-mod enabled → its 53 perks / 17 extra tracks render after the vanilla rows
      (38 tracks total incl. vanilla).
- [ ] Free-mode grant with modded perks owned → renown net-zero (per-prefix cost value
      counts modded perks).
- [ ] Mod that replaces vanilla perk files → no duplicate buttons (duplicate-key exclusion).
- [ ] Two standalone sub-mods enabled together → tool warned at generation time;
      last-loads-wins behavior documented.
- [ ] Sub-mod enabled without the base DI mod → launcher orders base first (dependency
      declaration) or fails loudly, never silently.

---

## 🔑 New finding — the console `run` mechanism (possible true-dynamic path)

While researching the "Gain all Dynasty Legacies" cheat (the one that leaves renown negative),
it turned out to be a **hardcoded C++ console command** (`gain_all_dynasty_perks`) — not script.
It grants all perks **without deducting renown** (renown goes negative per your screenshot), which
confirms the console path bypasses costs entirely.

More interesting, vanilla's debug console window reveals:

```paradox
onclick = "[ExecuteConsoleCommand('run run.txt')]"
# tooltip: "LMB to execute script in run.txt, LMB+Shift: run_shift.txt, RMB: run_rmb.txt ..."
```

- The console `run` command executes a Paradox script file from the CK3 user folder
  (`Documents/Paradox Interactive/Crusader Kings III/run.txt`).
- `ExecuteConsoleCommand(...)` is callable from **any GUI** — so a mod button can trigger it.
- **Limitation:** every vanilla usage passes a *static string* — there is no evidence
  `ExecuteConsoleCommand` accepts dynamic arguments (e.g. concatenating a scope's dynasty ID).
  So we cannot pass the selected dynasty through this path from GUI alone.

**Possible use:** a "Gain ALL legacies (incl. mods)" button that runs a *generated*
`run.txt`-style file listing every `add_dynasty_perk` for the player's dynasty — but since the
console commands act on the *player's* dynasty and can't take our selected-dynasty argument,
this only covers the player dynasty and adds little over Phase 1. Parked unless dynamic args
are ever confirmed.

**Conclusion unchanged:** Phase 1 (generated per-perk toggle effects targeting the selected
dynasty via the player's `DI_dynasty_selected_dynasty` variable) remains the right core; the
same generator covers modded tracks via sub-mods (Phase 3).

---

## Appendix — Vanilla legacy tracks

> ⚠️ **v4 correction:** this hand-written table was inaccurate — the generator (which reads
> the real files) found **21 tracks / 105 perks**, and several key prefixes differ:
> `ce1_heroic_track` exists (5 perks, gate `legends`), and the TGP tracks are actually
> `tgp_chinese_legacy_*`, `tgp_japan_legacy_*`, `tgp_sea_legacy_*` (not `tgp_china_` /
> `tgp_southeast_asia_`). **Trust the generated files, not this table.** Keeping the table only
> as a rough orientation of which DLC owns which track.

| Track key | Source |
|---|---|
| `warfare_legacy_track` | base |
| `law_legacy_track` | base |
| `guile_legacy_track` | base |
| `blood_legacy_track` | base |
| `erudition_legacy_track` | base |
| `glory_legacy_track` | base |
| `kin_legacy_track` | base |
| `ep1_culture_legacy_track` | EP1 (Culture) |
| `ep2_activities_legacy_track` | EP2 (Activities) |
| `fp1_adventure_legacy_track` | FP1 (Northern Lords) |
| `fp1_pillage_legacy_track` | FP1 (Northern Lords) |
| `fp2_urbanism_legacy_track` | FP2 (Iberia) |
| `fp2_coterie_legacy_track` | FP2 (Iberia) |
| `fp3_khvarenah_legacy_track` | FP3 (Legacy of Persia) |
| `ce1_legitimacy_legacy_track` | CE1 (Legitimacy) |
| `mpo_nomad_legacy_track` | MPO (Khans of the Steppe) |
| `ep3_administrative_legacy_track` | EP3 (Administrative) |
| `tgp_southeast_asia_legacy_track` | TGP (Wandering Lords?) |
| `tgp_japan_legacy_track` | TGP |
| `tgp_china_legacy_track` | TGP (Celestial Legacy) |

Perk keys: `<prefix>_legacy_<1..5>` — e.g. `warfare_legacy_1`, `fp1_adventure_legacy_3`,
`tgp_china_legacy_5`. Verify exact keys per track in `common/dynasty_perks/*.txt` when writing
effects (105 perks total in vanilla).

## Appendix — Verified script API

| Effect/Trigger | Verified in | Notes |
|---|---|---|
| `add_dynasty_perk = <perk_key>` | `00_mongol_invasion_effects.txt` | Works in `dynasty` scope; **deducts renown** (compensated in Mongol event by `add_dynasty_prestige = 10000`) |
| `has_dynasty_perk = <perk_key>` | `varangian_events.txt`, `artifact_events.txt` | Trigger, usable in `dynasty` scope |
| `add_dynasty_prestige = <n>` | `00_mongol_invasion_effects.txt` | Renown add — usable as refund |
| `add_dynasty_prestige_level = <n>` | `00_mongol_invasion_effects.txt` | |
| `Dynasty.GetPrestige` / `GetNextPerkCost` / `GetNextPerkProgress` | vanilla GUI | Already used in your editor window |
| `Dynasty.GetNumberOfLegacies` | `window_ledger.gui` | Returns count only — not an iterable list |
| ~~`every_dynasty_perk`~~ / ~~`Dynasty.GetLegacies`~~ | searched, not found | Runtime enumeration NOT possible |

---

## How the game builds the modded legacy list (and why we can't emulate it at runtime)

The engine scans `common/dynasty_perks/` and `common/dynasty_legacies/` **from all loaded mods
and vanilla at startup**, merging them into an internal registry. That registry is exposed to GUI
only through two engine-owned view-models:

- `DynastyView.GetLegacies` (legacy window)
- `DynastyHouseView.GetLegacies` (dynasty house window)

Both are created by the C++ side when their game view opens — they cannot be constructed from
script or referenced from a modded window's datacontext. There is no `every_dynasty_perk` script
iterator either. **Runtime emulation is therefore not possible with current script/GUI APIs.**

The practical equivalent is **build-time enumeration** (Phase 1.0 in this doc): a generator
script scans the same `common/dynasty_perks/*.txt` files the engine scans — including every
supported perk mod's copy — and emits the toggle effects/GUI. Same result as dynamic, just
refreshed by re-running the generator instead of being live, and shipped as per-mod sub-mods
(Phase 3) so users without those mods see zero errors.
