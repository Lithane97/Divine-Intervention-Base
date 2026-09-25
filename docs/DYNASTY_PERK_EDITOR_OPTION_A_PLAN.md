# Dynasty Perk Editor — Option A Plan (Hybrid: reuse vanilla's legacy window)

> **⚠️ CLOSED — Test 1 FAILED (2026-08-31).** The gated override made perk buttons clickable,
> but `DynastyView.SelectPerk` re-validates dynast authority/renown internally in C++ and
> silently ignored the clicks. The override was removed. This document is kept as research
> background only — the scripted per-perk toggle grid (`DYNASTY_PERK_EDITOR_PLAN.md`, Phase 1)
> is the editor. Do not revive unless a future patch changes `SelectPerk` behavior.

> Companion to `DYNASTY_PERK_EDITOR_PLAN.md` (hardcoded-grid plan). This doc explores the
> alternative: **override vanilla's `window_dynasty_legacy.gui`** so its fully dynamic,
> mod-inclusive legacy tree can be used as the editor itself.
>
> Main motivation: **Workshop shareability** — no generator script, no per-mod compatibility
> patches. The tree renders whatever legacy tracks exist at runtime, from any mod.

---

## Why this is attractive

Vanilla's `window_dynasty_legacy.gui` (490 lines) already does everything the editor needs:

- **Fully dynamic** — `datamodel = "[DynastyView.GetLegacies]"` renders every track, including
  all mod-added ones, automatically. Zero maintenance when mods change.
- **Full tree UI** — perks, icons, tooltips, progress pips, trait selection popup — all native.
- **Openable for any dynasty** — `OpenGameViewData('dynasty_legacy_window', Dynasty.GetID)`
  accepts an arbitrary dynasty ID (verified: `window_dynasty_house.gui` uses exactly this to
  jump to other dynasties' trees).

The DI selection UI you already built (char picker → `DI_dynasty_selected_dynasty` variable)
plugs straight into this.

---

## Research findings (verified in game files)

### How the window works

| Concern             | Mechanism                                                                                                             | File:line                                                     |
| ------------------- | --------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| Dynasty binding     | `datacontext = "[DynastyView.GetDynasty]"`, opened via `OpenGameViewData('dynasty_legacy_window', Dynasty.GetID)` | `window_dynasty_legacy.gui:7`, `window_dynasty_house.gui` |
| Track list          | `datamodel = "[DynastyView.GetLegacies]"`                                                                           | :172, :197                                                    |
| Perk list per track | `datamodel = "[DynastyLegacy.GetPerks]"`                                                                            | :378                                                          |
| Buy button          | `onclick = "[DynastyView.SelectPerk( DynastyPerk.Self )]"`                                                          | :388                                                          |
| Buy gating          | `enabled = "[DynastyView.CanSelectPerk( DynastyPerk.Self )]"`                                                       | :387                                                          |
| Already-owned check | `visible = "[Not( Dynasty.HasPerk( DynastyPerk.Self ) )]"`                                                          | :386                                                          |
| Dynast-only text    | `visible = "[GetPlayer.IsDynast]"` vs `Not(GetPlayer.IsDynast)`                                                   | :129, :138                                                    |

### The two blockers (and their workarounds)

**Blocker 1 — `CanSelectPerk` disables buying for non-player / non-dynast cases.**
The loc confirms intent: *"You are not the dynast so you cannot spend renown to unlock Legacies."*
When you open another dynasty's tree, buttons are disabled.

**Blocker 2 — `DynastyPerk` exposes almost nothing to script.**
Only `GetNameNoTooltip`, `GetEffectDescription`, `Self`. **No `GetKey`, no scope link** (checked
`event_targets.log`). So a modified `onclick` **cannot tell our script which perk was clicked** —
we cannot replace the buy logic with our own scripted gui per-perk.

### The workaround that makes Option A viable

**Keep vanilla's own `DynastyView.SelectPerk` as the purchase mechanism** and override the
`enabled` condition. Two audit corrections shape the override:

**1. This is a cheat editor — prerequisites are explicitly unwanted.** The user wants *any perk
at any time*, so we deliberately do **not** keep `IsNextUnlockablePerk` ordering. The override
enables every unowned perk:

```paradox
# vanilla:
enabled = "[DynastyView.CanSelectPerk( DynastyPerk.Self )]"
# mod override (cheat mode: any unowned perk, any order):
enabled = "[Not( Dynasty.HasPerk( DynastyPerk.Self ) )]"
```

**2. The override affects every legacy window in the game, not just DI openings.** Vanilla has
*other* widgets keyed to the same conditions (locked shading at :398, next-perk pips at
:414/:429 using `IsNextUnlockablePerk`, dynast text at :129/:138). A naive override produces
contradictory UI (clickable button with locked shading). The override must be **gated** so
normal gameplay keeps vanilla rules:

```paradox
# editor mode is ON only when the DI editor flag variable is set:
#   (set/clear 'DI_legacy_editor_mode' from the DI editor window's open/close)
enabled = "[Or(
    And( GetVariableSystem.Exists('DI_legacy_editor_mode'), Not( Dynasty.HasPerk( DynastyPerk.Self ) ) ),
    DynastyView.CanSelectPerk( DynastyPerk.Self )
)]"
```

…and similarly gate the other `CanSelectPerk`-keyed widgets (locked shading at :398) so they
don't contradict the enabled state. The `IsNextUnlockablePerk` pips (:414/:429) can stay vanilla
— they're informational, and in cheat mode showing the "natural" next perk is still useful.

⚠️ **Stuck-flag hazard (v2 addition):** if the legacy window closes via Esc, the game-view
stack, or a load screen, the "clear on close" logic may never fire — leaving **every** legacy
window in cheat mode for the rest of the session. Defense-in-depth: clear
`DI_legacy_editor_mode` (a) when the DI editor window closes, **and** (b) make the cheat
condition itself verify the opened dynasty is the DI-selected one, e.g. gate on
`And( Exists('DI_legacy_editor_mode'), <Dynasty.GetID equals selected dynasty's ID> )`
(if the GUI equality data functions allow comparing against
`GetPlayer.MakeScope.Var('DI_dynasty_selected_dynasty').Dynasty.GetID`). The second form makes
a stuck flag harmless — worst case, cheat mode is enabled for a window showing exactly the
dynasty you selected in the editor anyway.

If the engine's `SelectPerk` does not re-validate dynast/renown internally (unknown — needs an
in-game test), this turns the tree into a free editor for **any** dynasty, with **all modded
tracks**, zero generator, zero compat patches.

⚠️ **This is the one unknown that decides everything** — see the expanded test matrix below.

---

## How much of the window UI can we edit? (answer: essentially all of it)

Copying the file into the mod gives **total freedom over layout, widgets, text, and behavior** —
it's a full replacement, not a patch. Concretely:

| What                                         | Editable?                   | Notes                                                                   |
| -------------------------------------------- | --------------------------- | ----------------------------------------------------------------------- |
| Layout, size, position, styling              | ✅ fully                    | It's our file now                                                       |
| Add new widgets (portraits, buttons, panels) | ✅ fully                    | Can embed the`DI_Dynasty_Select_Character` template, DI buttons, etc. |
| `visible` / `enabled` conditions         | ✅ fully                    | This is the`CanSelectPerk` bypass                                     |
| Text / localization                          | ✅ fully                    |                                                                         |
| `onclick` behavior                         | ⚠️ partially — see below | The data you can pass to script is the limit                            |

**Adding your portrait character switcher: yes, easily.** The window is just a widget tree; you can
drop in `using = DI_Dynasty_Select_Character` (your existing template) or any DI widget, plus
`GetVariableSystem` toggles, scripted-gui buttons, whatever. The only thing to keep in mind is that
the window's root datacontext is `[DynastyView.GetDynasty]` — your added widgets can use their own
`datacontext` lines (like your editor window does with `GetPlayer.MakeScope.Var(...)`) to access
DI variables. Your existing UI being "based on it anyway" makes this trivial.

## Why can't we just change what clicking a perk button does?

Because of **what the button is allowed to tell script**, not because of the click itself:

1. Changing `onclick` is trivial — e.g. `onclick = "[GetScriptedGui('DI_x').Execute(...)]"`.
2. The problem is the **arguments**. Our script effect needs to know *which perk* to grant
   (`add_dynasty_perk = <key>`). Passing a scope works via `GuiScope.SetRoot(...).AddScope(...)`
   (vanilla does this with `Faith.MakeScope`, `Character.MakeScope`, etc.) — **but that requires
   the object to have a `MakeScope` / scope link.**
3. Verified against the script docs: `DynastyPerk` has **no scope link** (not in
   `event_targets.log`) and exposes only `GetNameNoTooltip`, `GetEffectDescription`, `Self` —
   **no `GetKey`**. `DynastyLegacy` (the track) likewise has no key/scope access.
4. So a clicked perk button cannot communicate "I am `warfare_legacy_2`" to script. The engine's
   `DynastyView.SelectPerk` can do it because it's C++ with direct registry access.

### What this means practically

| Click behavior change                                                                             | Possible?                                             |
| ------------------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| Enable buying for any dynasty (keep`SelectPerk`)                                                | ✅ — the`enabled` override (Test 1)                |
| Add DI widgets/portraits around the tree                                                          | ✅ freely                                             |
| Route the click to our own script**per perk**                                               | ❌ no perk key/scope access                           |
| Route the click to our own script**per track**                                              | ❌ same problem (no track key access)                 |
| Add separate DI buttons (e.g. "add next perk in<hardcoded track></hardcoded>") alongside the tree | ✅ — those buttons don't need the tree's datacontext |

So the realistic Option A shape is: **vanilla tree (with `enabled` bypass) for viewing + buying,
plus your DI selection UI embedded, plus optional hardcoded DI buttons for features the tree
can't do** (remove-perk, exact renown refund). If Test 1 shows `SelectPerk` re-validates and
refuses for other dynasties, the tree degrades to a viewer and granting falls back to the
hardcoded buttons — the two plans merge rather than compete.

### Test 1 — proof of concept (do this first)

**Prerequisite:** complete Phase 0 baseline cleanup in `DYNASTY_PERK_EDITOR_PLAN.md` first —
the current WIP has parser errors that would pollute `gui_warnings.log` and make results
ambiguous.

1. Copy `H:\SteamLibrary\...\game\gui\window_dynasty_legacy.gui` into the mod's `gui/` folder,
   based **exactly on the installed 1.19.0.6 vanilla file**.
2. Apply the gated `enabled` override shown above (cheat mode: any unowned perk, any order).
3. Run the expanded test matrix. **Pass criterion: the perk actually gets granted — a clickable
   button alone proves nothing** (a C++ command likely validates authority/order/renown
   internally).

| # | Case | Expectation to verify |
|---|---|---|
| 1 | Player dynasty, enough renown | Buy works; renown deducted |
| 2 | Player dynasty, insufficient renown | Cheat mode: buy succeeds; renown goes negative or grant fails — record which |
| 3 | Foreign dynasty (not player's), enough renown | **The critical case** — does the perk actually get granted? |
| 4 | Foreign dynasty, insufficient renown | As above with cost involved |
| 5 | Out-of-order perk (tier 3 with 0 owned) | Cheat mode should grant it — confirm no engine veto |
| 6 | Perk with associated-trait confirmation popup | Does the confirmation flow complete for foreign dynasties? |
| 7 | Renown before/after each case | Record exact numbers (screenshot the tooltip) |
| 8 | Persistence | Close window, re-open; save + reload — perks persist? |
| 9 | Logs after every case | `error.log` + `gui_warnings.log` clean of new entries |

**Outcomes:**

- ✅ Case 3 grants the perk → Option A is fully viable; continue with steps below.
- ❌ Clickable but nothing happens / error → engine re-validates; the tree stays a **viewer**,
  granting falls back to the generated scripted editor (Phase 1 of the other plan). This is the
  expected outcome per the audit — don't burn more time on A if it fails.
- ❌ Buttons still disabled → `enabled` isn't the only gate; inspect `gui_warnings.log` and
  reconsider.

### Step 2 — Integrate with the DI selection flow

- Keep your existing char/dynasty picker (`DI_dynasty_selected_dynasty` variable).
- The DI editor window's "Edit Legacies" button sets the `DI_legacy_editor_mode` variable, then:
  ```paradox
  onclick = "[OpenGameViewData( 'dynasty_legacy_window',
      GetPlayer.MakeScope.Var('DI_dynasty_selected_dynasty').Dynasty.GetID )]"
  ```
- Closing the legacy window / the DI editor clears `DI_legacy_editor_mode` so ordinary legacy
  tree openings keep vanilla rules.

### Step 3 — Renown handling (two explicit modes)

The cost formula is `250 + TOTAL unlocked perks × 500` (dynasty-wide, not per-track position) —
so per-perk refund math is unreliable. Offer two explicit modes instead:

- **Free edit (default for a cheat tool):** a "Renown +10000" button in the DI editor window;
  click before buying so purchases never fail. Disclose that this inflates renown *level*
  progress (unavoidable — level derives from total prestige gained).
- **Normal cost:** buy with renown as-is, vanilla behavior.

### Step 4 — Workshop-safe packaging

- The override file lives at `gui/window_dynasty_legacy.gui` in the mod — **no generator, no
  external tools, fully shareable**.
- ⚠️ **Compatibility caveat:** any other mod that *also* replaces `window_dynasty_legacy.gui`
  will conflict (last-in-load-order wins). Legacy-tree UI mods are rare, but check compatibility
  notes before publishing. This is the same conflict class as any UI overhaul mod — normal and
  accepted on the Workshop.
- ⚠️ **Patch-day maintenance (v2 addition):** a full copy of the vanilla file silently goes
  stale on every major patch (you'd be shipping a 1.19 file into a 1.20 game). Release
  checklist item: after each CK3 patch, diff the new vanilla `window_dynasty_legacy.gui`
  against your override and re-apply your changes onto the new base. Budget ~15 min per patch,
  and verify the datafunctions you rely on (`CanSelectPerk`, `IsNextUnlockablePerk`,
  `SelectPerk`) still exist.

### Step 5 — Optional polish

- Also override the `visible = "[GetPlayer.IsDynast]"` explanation text to show a
  "Divine Intervention editor mode" note.
- Add right-click handling? Not possible per-perk (no key access) — removal stays with
  `remove_dynasty_perk` buttons in the DI window (hardcoded grid, Phase 2 of the other plan),
  or console.

---

## Option A′ — fallback if Test 1 fails

If the engine re-validates inside `SelectPerk`, the override can still change `onclick` — but
since `DynastyPerk` has no key/scope exposure, per-perk script calls are impossible. The remaining
Option A′ shape:

- Override the window to **remove gating** and change each perk button to open a small
  DI confirmation popup that grants via **positional logic**: the button's index within
  `DynastyLegacy.GetPerks` datamodel is knowable in GUI (`GetDataModelSize`/iteration order) but
  there is no clean way to pass it to script either. Practically, A′ collapses into the
  hardcoded-grid plan (`DYNASTY_PERK_EDITOR_PLAN.md`) with the vanilla tree kept as a
  *viewer* via `OpenGameViewData`.

---

## Comparison with the hardcoded plan

|                          | Option A (this doc)                | Hardcoded grid (other doc)         |
| ------------------------ | ---------------------------------- | ---------------------------------- |
| Modded tracks            | ✅ automatic                       | ⚠️ via generator re-run          |
| Workshop shareable       | ✅ yes (one file override)         | ⚠️ generator is external tooling |
| Add perks to any dynasty | ❓ pending Test 1                  | ✅ yes (selected dynasty variable) |
| Remove perks             | ❌ not per-perk                    | ✅`remove_dynasty_perk`          |
| Renown handling          | cheat button                       | exact per-perk refund              |
| Maintenance              | vanilla file copy (patch-day risk) | self-owned files                   |
| UI work                  | ~none (vanilla tree)               | build a grid                       |

**Recommendation (v2, post-audit):** order of operations is now fixed across both docs:
**Phase 0 cleanup → Test 1 (this doc) → the generated scripted editor (other doc) is built
regardless.** If Test 1 passes, Option A becomes the viewing/buying UI and the scripted grid
handles removal and renown control — complementary, not competing. If it fails (the honest
expectation — C++ commands usually re-validate authority internally), Option A degrades to a
read-only preview opened via `OpenGameViewData`, and no further time goes into it. Either way
the scripted per-perk toggle grid is the non-negotiable core; Option A is a bonus.

---

## References

- Vanilla window: `H:\SteamLibrary\steamapps\common\Crusader Kings III\game\gui\window_dynasty_legacy.gui` (490 lines)
- Open call example: `...\game\gui\window_dynasty_house.gui`
- Script docs: `Documents/Paradox Interactive/Crusader Kings III/logs/effects.log` (`add_dynasty_perk`, `remove_dynasty_perk` — dynasty scope)
- Dynast gating loc: `DYNASTY_VIEW_SHOW_LEGACY_EXPLANATION_NOT_HEAD`
