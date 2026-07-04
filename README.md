# Divine Intervention - Base

About
-----
Divine Intervention - Base is a mod for Crusader Kings III that provides the foundational files and shared assets used by the Divine Intervention mod family. It contains the core scripts, localization, and data required by the Divine Intervention sub-mods and is intended to be installed alongside any mod that depends on it.

Installation
------------
These instructions assume Crusader Kings III is installed and that you are installing the mod from this repository or a release ZIP.

Manual install
- Locate your CK3 mods folder:
  - Windows: %USERPROFILE%\Documents\Paradox Interactive\Crusader Kings III\mod
  - Linux: ~/.local/share/Paradox Interactive/Crusader Kings III/mod
  - macOS: ~/Documents/Paradox Interactive/Crusader Kings III/mod
- Download the release ZIP or clone this repository and copy the folder named `Divine-Intervention` into the `mod` folder above.
- Ensure the CK3 `mod` folder contains both:
  - `Divine-Intervention/` (the folder with the mod contents)
  - `Divine-Intervention.mod` (the launcher descriptor file placed next to the folder)
- Start the Paradox Launcher, add this mod to your intended playset, and select the playset before launching the game.

Local descriptor template
- This repo includes `Divine Intervention.local_descriptor.template.txt` as a starter launcher descriptor.
- Copy it into the CK3 `mod` folder alongside the `Divine-Intervention` folder, rename the copy to `Divine-Intervention.mod`, and update the `path=` value.
- Use `path="mod/Divine-Intervention"` for a portable local install, or your own absolute path if located outside of the mod folder.

```text
version="0.4.0"
tags={
	"Utilities"
}
name="Divine Intervention Cheat Menu"
supported_version="1.19.0.4"
path="mod/Divine-Intervention"
remote_file_id="2986538297"
```

Notes
- Prefer a relative path for portability, e.g.:
  path="mod/Divine-Intervention"
- Use an absolute path only if you need the mod to point outside the mods folder; if so, replace <YOUR_USER> with your username and adjust the rest to match your system.
- If distributing via Steam Workshop, `remote_file_id` may be used; otherwise it can be omitted.

Troubleshooting
- If changes are not visible after editing files, fully exit CK3 and the Paradox Launcher, then relaunch.
- Make sure the folder name and `.mod` descriptor path match exactly.
- Confirm the mod is enabled in the playset you selected in the Paradox Launcher.
- If a dependent sub-mod is failing to show changes, ensure this base mod appears earlier/higher in the playset load order and the sub-mod appears later/lower.

License and Contact
- No formal licence file is included in this repository. The mod is published for use with Crusader Kings III under the terms and allowances provided by Paradox Interactive to the modding community; consult Paradox Interactive's EULA and modding policies if you need explicit legal guidance.
- For issues, questions, or help installing, open an issue in this repository or contact the maintainer via GitHub: @Lithane97.
