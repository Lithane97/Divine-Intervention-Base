# Dynasty Legacy Perk Editor — Research & Implementation Options

> ⚠️ **HISTORICAL RESEARCH DOCUMENT — superseded.**
> This was written before the script documentation was generated. Since then:
> - `add_dynasty_perk` / `remove_dynasty_perk` were confirmed to exist (effects.log).
> - **No** dynasty-perk/legacy iterator exists → **Option B is REJECTED** (its dynamic
>   script-built list is impossible).
> - Option D has been merged into Option A (it was a less precise version of the same idea).
>
> **Authoritative implementation plans (both at v2, audit-refined):**
> - `DYNASTY_PERK_EDITOR_PLAN.md` — **generator-produced** per-perk toggle editor (the
>   dependable path, non-negotiable core). v2: generator moved to Phase 1 step 0, per-perk
>   toggles replace "add next" chains, example scope bugs fixed, sub-mod shipping model added.
> - `DYNASTY_PERK_EDITOR_OPTION_A_PLAN.md` — vanilla-window override experiment (small test
>   effort, biggest payoff if foreign-dynasty purchasing works). v2: stuck-flag mitigation,
>   patch-day checklist, fixed execution order (Phase 0 → Test 1 → scripted core regardless).
>
> The vanilla research below remains accurate and useful as background.

---

> Status: **Work in progress** (branch `Adding-Dynasty-Legacy-Perk-Picking`)
> Goal: Dynamically list and grant **all** dynasty legacy tracks (including mod-added ones) for an
> arbitrary selected dynasty, from a custom editor window in the Divine Intervention menu.

---

## Background — what already exists on this branch

| File | Purpose |
|---|---|
| `gui/DI_dynasty_perk_editor.gui` | Main editor window. Datacontext bound to `GetPlayer.MakeScope.Var('DI_dynasty_selected_dynasty').Dynasty`. Shows renown, next-perk cost, progress bar. |
| `gui/DI_dynasty_perk_editor_templates/DI_dynasty_select_character.gui` | "Dynasty to Edit" portrait selector (copies the culture-editor pattern). |
| `gui/DI_dynasty_perk_editor_templates/DI_dynasty_perk_editor_templates.gui` | 2,153 lines of commented-out vanilla `window_dynasty_house.gui` code — study notes on how vanilla renders legacies. |
| `gui/DI_dynasty_perk_editor_templates/DI_dynasty_select_character.gui` | Second selector ("Dynasty to Copy") for copying legacies from another dynasty. |
| `common/scripted_guis/DI_dynasty_perk_editor_sgui.txt` | Stores selection in player-scope vars: `DI_dynasty_selected_char`, `DI_dynasty_selected_dynasty` (+ `_copy` variants). |
| `gui/DI_main.gui` | "Dynasty Perks Editor" button in the main DI window. |
| `gui/scripted_widgets/DI_scripted_widgets.txt` | Widget registrations for the dynasty windows. |

### Where work stopped
- Attempted `set_data_model` with a `dynasty_legacy_browser` type — **does not exist**, dead end.
- Attempted `DI_Dynastey_perk_list` to build a global list of legacies — references undefined
  `scope:legacy`, never worked.
- Commit messages: *"Now Stuck at getting list of all Dynasties Perk Tracks / Legacies"*.

---

## Vanilla research findings (verified against game files, patch 1.19)

Game install used for research: `H:\SteamLibrary\steamapps\common\Crusader Kings III\game`

### How vanilla renders legacies dynamically

`gui/window_dynasty_legacy.gui` (the legacy tree window):

```paradox
window = {
    name = "dynasty_legacy_window"
    widgetid = "dynasty_legacy_window"
    datacontext = "[DynastyView.GetDynasty]"     # DynastyView is a C++ view-model
    ...
    datamodel = "[DynastyView.GetLegacies]"      # ← dynamic list of ALL legacy tracks (modded included)
    ...
    datamodel = "[DynastyLegacy.GetPerks]"       # ← perks inside each track
}
```

Key types observed in vanilla GUI:

| Type | Exposed methods (found in vanilla .gui usage) |
|---|---|
| `DynastyView` | `GetDynasty`, `GetLegacies` — **only exists inside the game-view-bound legacy window** |
| `DynastyLegacy` | `GetDesc`, `GetIcon`, `GetName`, `GetPerks`, `GetTrackIcon` |
| `DynastyPerk` | `GetEffectDescription`, `GetNameNoTooltip` |
| `DynastyLegacyItem` | `GetTooltip`, `GetUnlockedPerksCount` |
| `Dynasty` | `GetID`, `GetPrestige`, `GetNextPerkProgress`, `GetNumberOfLegacies`, `GetDynast`, `GetCulture`, ... — **no `GetLegacies`** |

### How vanilla opens the legacy window for an arbitrary dynasty

```paradox
onclick = "[OpenGameViewData( 'dynasty_legacy_window', Dynasty.GetID )]"
```

The window accepts a **dynasty ID** — it is not hardwired to the player's dynasty.

### Key constraint discovered
`DynastyView` is a C++ view-model created by the engine when the game view opens. It **cannot be
created from script or from a modded window's datacontext**. That is why `set_data_model` with a
made-up type failed, and why `Dynasty.GetLegacies` does not exist for script-side datacontexts.

---

## Option A — Hybrid: reuse vanilla's legacy window

**Idea:** Keep the DI selection UI, then open vanilla's legacy window pointed at the selected dynasty.

```paradox
onclick = "[OpenGameViewData( 'dynasty_legacy_window', GetPlayer.MakeScope.Var('DI_dynasty_selected_dynasty').Dynasty.GetID )]"
```

- ✅ Zero UI work — full dynamic tree, modded legacies included
- ✅ Selection flow already built
- ❌ Cannot add perks from our own UI; vanilla window likely blocks *buying* for non-player dynasties
- ❌ Would still need a separate cheat effect to grant perks / refund renown

**Effort:** Low. **Risk:** Low. **Dynamic:** Yes (vanilla handles it).

---

## Option B — Script-driven dynamic list (**REJECTED** — see header)

**Idea:** Use **script** (not GUI) to enumerate legacy tracks into a saved list, then read that list
in GUI via `GetPlayer.MakeScope.GetList('...')` — the same pattern the mod already uses for
`pinned_characters` in the char-select lists.

### Step B1 — Generate script documentation (do this first)

Launch CK3 once with debug launch options; the game writes full effect/trigger docs to the logs folder:

```
Steam → CK3 → Properties → Launch Options:
-debug_mode -script_doc
```

Generated files (in `Documents/Paradox Interactive/Crusader Kings III/logs/`):
- `effects.log` — every scripted effect with arguments (look for `dynasty`, `legacy`, `perk`)
- `triggers.log` — every trigger
- `events.log` — event/script documentation

**What to search for in `effects.log`:** anything like `dynasty_add_legacy_perk`, `add_legacy`,
`unlock_legacy`, `dynasty_*perk*`. Debug/hidden effects are included in the dump. This definitively
answers whether script can (a) grant legacy perks and (b) iterate legacy definitions.

> Note: `-debug_mode` taints saves and enables console — launch once for docs, then remove the option.

### Step B2 — Enumerate legacies into a list (if script supports it)

If the docs reveal a way to iterate legacy definitions (e.g. `every_legacy_track` or a global list),
populate a global list the same way `DI_Dynastey_perk_list` attempted:

```paradox
DI_build_legacy_list = {
    scope = character
    effect = {
        # pseudo — exact effect names TBD from effects.log
        # every_legacy_track = {
        #     add_to_global_variable_list = { name = DI_all_legacy_tracks target = prev }
        # }
    }
}
```

Then in GUI:

```paradox
datamodel = "[GetPlayer.MakeScope.GetList('DI_all_legacy_tracks')]"
```

### Step B3 — Grant perks

Once the effect name is known (from `effects.log`), wire each legacy entry to a grant effect that
operates on the selected dynasty:

```paradox
DI_dynasty_grant_next_perk = {
    scope = character
    effect = {
        scope:DI_dynasty_selected_dynasty.Dynasty = {
            # <grant effect from docs, targeting a specific legacy track>
        }
    }
}
```

- ✅ Fully dynamic — modded legacies included automatically
- ✅ Fits the mod's existing patterns (variable lists + `GetList` datamodels)
- ❌ Blocked until `effects.log` confirms the effects exist
- ❌ If no iteration effect exists, fall back to a hardcoded track list (Option C)

**Effort:** Medium. **Risk:** Depends on docs. **Dynamic:** Yes.

---

## Option C — Hardcoded legacy track grid (fallback)

**Idea:** Skip enumeration. Build a fixed grid of buttons — one per known legacy track — exactly like
the mod's lifestyle present buttons (`DI_lifestyle_present_effects.txt` hardcodes every perk).

```paradox
DI_dynasty_add_warfare_perk = { ... }
DI_dynasty_add_learning_perk = { ... }
# ~10 tracks
```

- ✅ Works with zero engine research beyond the grant effect
- ❌ Not dynamic — new mod-added legacies need manual additions
- ❌ Conflicts with the stated goal (AGOT + other legacy mods add many tracks)

**Effort:** Medium. **Risk:** Low. **Dynamic:** No.

---

## Option D — Copy vanilla's legacy window into the mod (speculative)

**Idea:** Copy `window_dynasty_legacy.gui` into the mod under a new name/widgetid and test whether
`DynastyView` still resolves when opened via `OpenGameViewData` with a custom dynasty ID. If it does,
add "grant perk" buttons directly into the copied tree UI.

- ✅ Full dynamic tree UI under our control
- ❌ Depends on undocumented engine behavior — `DynastyView` may refuse to bind outside vanilla's window
- ❌ Large maintenance surface (copy of vanilla file)

**Effort:** Medium-high. **Risk:** High. **Dynamic:** Yes, if it works.

---

## Recommendation / roadmap

1. **Now:** Generate script docs (Step B1) — one game launch with `-debug_mode -script_doc`.
2. **Then:** Grep `effects.log` for legacy/perk effects. This decides B vs C:
   - Iteration + grant effects exist → **Option B**
   - Only grant effects exist → **B for granting + C's hardcoded grid for listing**
   - Nothing exists → **Option A** (hybrid) is the only dynamic path
3. **Cleanup when resuming code:**
   - Delete `DI_Dynastey_perk_list` (references undefined `scope:legacy`, dead code)
   - Remove the empty `if = { limit = {...} }` in `DI_dynasty_selected_char_copy`
   - Remove the dead second `datacontext = "[GetPlayer]"` line in `DI_dynasty_perk_editor.gui`
     (only the last `datacontext` wins)
   - Typo: `DI_Dynastey_perk_list` → `DI_Dynasty_perk_list`

## Useful references

- Vanilla legacy window: `H:\SteamLibrary\steamapps\common\Crusader Kings III\game\gui\window_dynasty_legacy.gui`
- Vanilla dynasty house window: `...\game\gui\window_dynasty_house.gui`
- Existing perk-grant precedent (lifestyle perks): `common/scripted_effects/DI_lifestyle_present_effects.txt`
- Existing variable-list GUI pattern: char-select lists in `gui/DI_misc.gui` (`GetList('pinned_characters')`)
- Paradox wiki — GUI scripting: https://ck3.paradoxwikis.com/Graphics_modding
- Paradox wiki — Effects: https://ck3.paradoxwikis.com/Effects
