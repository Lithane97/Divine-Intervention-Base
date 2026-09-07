# =============================================================================
# _grid_templates.ps1 - SHARED vanilla-look grid emit (dot-sourced by both generators)
# =============================================================================
# DEFINITIONS ONLY - this file must never run top-level code. It is dot-sourced by
# generate_perk_editor.ps1 / generate_mod_perks.ps1, which own the parse, the
# StringBuilder, the encoding and the actual file writes; this module only turns one
# track (or one perk) into GUI text via the two writers below.
#
# Helpers (call after dot-sourcing):
#   Write-VanillaTrackSection $Sb $Track $PerkList $Gate   -> one track section
#   Write-VanillaPerkButton   $Sb $Key    $Track           -> one perk button
#
# Look is modelled on the vanilla legacy window
# (game/gui/window_dynasty_legacy.gui, hbox_legacy_item + perk button): 80x80 track
# icon, localized <track>_name / <track>_desc header, then 296x128 perk buttons on a
# mask_frame_horizontal / tile_frame_thin_02 background.
#
# Buttons are ALWAYS ENABLED (no `enabled = GetScriptedGui(...).IsValid(...)`):
# that binding tracks the *add* direction, so once a perk is owned the widget gets
# disabled and onrightclick (remove) can never dispatch. Left click = add (no-op if
# already owned, guarded by the add SGUI's is_shown), right click = remove (no-op if
# not owned). Out-of-order add/remove is intended.
# =============================================================================

# --- One perk button (296x128), wired to DI_perk_add_<key> / DI_perk_remove_<key> --
function Write-VanillaPerkButton {
    param($Sb, [string]$Key, [string]$Track, [switch]$DisableOwnedState)
    [void]$Sb.AppendLine("                button_standard = {")
    [void]$Sb.AppendLine("                    size = { 296 128 }")
    [void]$Sb.AppendLine("                    button_ignore = none")
    [void]$Sb.AppendLine("                    onclick = ""[GetScriptedGui('DI_perk_add_$Key').Execute(GuiScope.SetRoot(GetPlayer.MakeScope).End)]""")
    [void]$Sb.AppendLine("                    onrightclick = ""[GetScriptedGui('DI_perk_remove_$Key').Execute(GuiScope.SetRoot(GetPlayer.MakeScope).End)]""")
    [void]$Sb.AppendLine('                    tooltip = "DI_perk_tt_' + $Key + '"')
    [void]$Sb.AppendLine("")
    [void]$Sb.AppendLine("                    background = {")
    [void]$Sb.AppendLine("                        size = { 100% 100% }")
    [void]$Sb.AppendLine("                        texture = ""gfx/interface/component_masks/mask_frame_horizontal.dds""")
    [void]$Sb.AppendLine("                        tintcolor = { 0 0 0 0.7 }")
    [void]$Sb.AppendLine("                        alpha = 0.9")
    [void]$Sb.AppendLine("                    }")
    [void]$Sb.AppendLine("")
    # owned layer: gold border (frame, not a fill) + checkmark, visible only when
    # the selected dynasty owns the perk. FIX-4a: the visibility bindings are PURE
    # datafunctions (Dynasty.HasPerk over GetDynastyPerk) - the previous
    # GetScriptedGui IsShown form executed a scripted-gui trigger per cell per
    # binding re-evaluation (2,554 script runs per wave), which correlated with
    # machine freezes. Effects stay on onclick/onrightclick (click-time only).
    if (-not $DisableOwnedState) {
    [void]$Sb.AppendLine("                    background = {")
    [void]$Sb.AppendLine("                        visible = ""[Dynasty.HasPerk( GetDynastyPerk('$Key') )]""")
    [void]$Sb.AppendLine("                        size = { 100% 100% }")
    [void]$Sb.AppendLine("                        using = Background_Frame_Gold")
    [void]$Sb.AppendLine("                        alwaystransparent = yes")
    [void]$Sb.AppendLine("                    }")
    [void]$Sb.AppendLine("")
    [void]$Sb.AppendLine("                    icon = {")
    [void]$Sb.AppendLine("                        visible = ""[Dynasty.HasPerk( GetDynastyPerk('$Key') )]""")
    [void]$Sb.AppendLine("                        parentanchor = top|right")
    [void]$Sb.AppendLine("                        position = { -4 4 }")
    [void]$Sb.AppendLine("                        texture = ""gfx/interface/icons/symbols/icon_check.dds""")
    [void]$Sb.AppendLine("                        size = { 24 24 }")
    [void]$Sb.AppendLine("                        alwaystransparent = yes")
    [void]$Sb.AppendLine("                    }")
    [void]$Sb.AppendLine("")
    }
    [void]$Sb.AppendLine("                    vbox = {")
    [void]$Sb.AppendLine("                        margin = { 10 5 }")
    [void]$Sb.AppendLine("                        margin_top = 18")
    [void]$Sb.AppendLine("")
    # ladder 4: fixed-size text_single - text_multi autoresize re-measures 1,277
    # cells at layout time; names are single-line so the dynamic re-measure is cost
    # without benefit.
    [void]$Sb.AppendLine("                        text_single = {")
    [void]$Sb.AppendLine('                            text = "[Localize(''' + $Key + '_name'')]"')
    [void]$Sb.AppendLine("                            max_width = 296")
    [void]$Sb.AppendLine("                            fontsize_min = 14")
    [void]$Sb.AppendLine("                            default_format = ""#low""")
    [void]$Sb.AppendLine("                        }")
    [void]$Sb.AppendLine("                    }")
    [void]$Sb.AppendLine("                }")
    [void]$Sb.AppendLine("")
}

# --- One track section: vanilla-style header + flowcontainer of perk buttons -----
# $Gate is a DLC feature name (or empty); when set the whole section is hidden with
# visible = "[HasDlcFeature( '<gate>' )]" so a missing DLC leaves no dead buttons.
function Write-VanillaTrackSection {
    param($Sb, [string]$Track, $PerkList, [string]$Gate, [switch]$DisableOwnedState)
    if (@($PerkList).Count -eq 0) { throw "Cannot generate empty dynasty track '$Track'." }
    [void]$Sb.AppendLine("        # ---- $Track ($($PerkList.Count) perks)$(if ($Gate) { "" [DLC: $Gate]"" }) ----")
    [void]$Sb.AppendLine("        vbox = {")
    if ($Gate) {
        [void]$Sb.AppendLine("            visible = ""[HasDlcFeature( '$Gate' )]""")
    }
    [void]$Sb.AppendLine("            layoutpolicy_horizontal = expanding")
    [void]$Sb.AppendLine("            spacing = 5")
    [void]$Sb.AppendLine("")
    [void]$Sb.AppendLine("            hbox = {")
    [void]$Sb.AppendLine("                layoutpolicy_horizontal = expanding")
    [void]$Sb.AppendLine("                spacing = 10")
    [void]$Sb.AppendLine("")
    [void]$Sb.AppendLine("                icon = {")
    [void]$Sb.AppendLine("                    size = { 80 80 }")
    [void]$Sb.AppendLine("                    texture = ""gfx/interface/icons/dynasty/$Track.dds""")
    [void]$Sb.AppendLine("                }")
    [void]$Sb.AppendLine("")
    [void]$Sb.AppendLine("                vbox = {")
    [void]$Sb.AppendLine("                    layoutpolicy_horizontal = expanding")
    [void]$Sb.AppendLine("                    margin = { 5 5 }")
    [void]$Sb.AppendLine("                    spacing = 2")
    [void]$Sb.AppendLine("")
    [void]$Sb.AppendLine("                    text_single = {")
    [void]$Sb.AppendLine("                        layoutpolicy_horizontal = expanding")
    [void]$Sb.AppendLine('                        text = "[Localize(''' + $Track + '_name'')]"')
    [void]$Sb.AppendLine("                        default_format = ""#high""")
    [void]$Sb.AppendLine("                        using = Font_Size_Medium")
    [void]$Sb.AppendLine("                        fontsize_min = 14")
    [void]$Sb.AppendLine("                    }")
    [void]$Sb.AppendLine("")
    [void]$Sb.AppendLine("                    text_multi = {")
    [void]$Sb.AppendLine("                        layoutpolicy_horizontal = expanding")
    [void]$Sb.AppendLine('                        text = "[Localize(''' + $Track + '_desc'')]"')
    [void]$Sb.AppendLine("                        maximumsize = { -1 90 }")
    [void]$Sb.AppendLine("                        fontsize_min = 14")
    [void]$Sb.AppendLine("                    }")
    [void]$Sb.AppendLine("                }")
    [void]$Sb.AppendLine("")
    [void]$Sb.AppendLine("                button_standard = {")
    [void]$Sb.AppendLine("                    size = { 130 26 }")
    [void]$Sb.AppendLine("                    text = DI_DYNASTY_EDITOR_TRACK_BUTTON")
    [void]$Sb.AppendLine("                    onclick = ""[GetScriptedGui('DI_track_add_all_$Track').Execute(GuiScope.SetRoot(GetPlayer.MakeScope).End)]""")
    [void]$Sb.AppendLine("                    onrightclick = ""[GetScriptedGui('DI_track_remove_all_$Track').Execute(GuiScope.SetRoot(GetPlayer.MakeScope).End)]""")
    [void]$Sb.AppendLine("                    tooltip = DI_DYNASTY_EDITOR_TRACK_BUTTON_TT")
    # fully-owned tint: pure datafunction form (FIX-4a) - And over the track's perk
    # keys; the old IsShown bindings executed a scripted-gui trigger per track per
    # re-evaluation wave (262+ script runs per flip).
    if (-not $DisableOwnedState) {
    $terms = @($PerkList | ForEach-Object { "Dynasty.HasPerk( GetDynastyPerk('$_') )" })
    $ownedExpr = $terms[-1]
    for ($i = $terms.Count - 2; $i -ge 0; $i--) {
        $ownedExpr = "And( $($terms[$i]), $ownedExpr )"
    }
    [void]$Sb.AppendLine("                    blockoverride ""background_color"" {")
    [void]$Sb.AppendLine("                        background = {")
    [void]$Sb.AppendLine("                            visible = ""[$ownedExpr]""")
    [void]$Sb.AppendLine("                            using = Background_Frame_Gold")
    [void]$Sb.AppendLine("                        }")
    [void]$Sb.AppendLine("                        background = {")
    [void]$Sb.AppendLine("                            visible = ""[Not( $ownedExpr )]""")
    [void]$Sb.AppendLine("                            using = Background_Color")
    [void]$Sb.AppendLine("                        }")
    [void]$Sb.AppendLine("                    }")
    }
    [void]$Sb.AppendLine("                }")
    [void]$Sb.AppendLine("            }")
    [void]$Sb.AppendLine("")
    [void]$Sb.AppendLine("            flowcontainer = {")
    [void]$Sb.AppendLine("                layoutpolicy_horizontal = expanding")
    [void]$Sb.AppendLine("                spacing = 5")
    [void]$Sb.AppendLine("")
    foreach ($k in $PerkList) {
        Write-VanillaPerkButton $Sb $k $Track -DisableOwnedState:$DisableOwnedState
    }
    [void]$Sb.AppendLine("            }")
    [void]$Sb.AppendLine("        }")
    [void]$Sb.AppendLine("")
}

