# Divine Intervention Feature Inventory

This inventory is organized by the way a player reaches each feature in game. It covers the character interactions exposed through the Divine Intervention interaction category and the GUI features reached from the skull button menu.

## 1. Access Points

### Skull Button

The mod adds a round skull/execute-style button near the bottom right of the HUD. Pressing it toggles the **Divine Intervention Cheat Menu**.

The button is hidden while the pause menu, observer mode, right-side windows, the barbershop, or the royal court view are active. A character interaction can also toggle whether this button is shown.

### Main Cheat Menu

The main menu is a movable window with three rows of major tools plus utility buttons.

- **Character Editor**: Opens the character editor. This includes presents, skills, perk points, modifiers, traits, sexuality, culture, and religion tools. Toggling the pinned checkbox allows editing of any characters in the pinned character list.
- **Pinned Characters**: Opens the pinned-character management window for reviewing pinned characters and changing currencies, skills, culture, religion, and titles.
- **Title Manager**: Opens the pinned-title manager for title, de jure, culture, religion, province, holding, and building actions.
- **Event Manager**: Debug-only proof-of-concept event window.
- **Character Spawner**: Opens a tool for generating family members, councillors, courtiers, commanders, knights, and court-position characters.
- **Army Spawner**: Opens a tool for spawning men-at-arms and special units in configurable amounts.
- **Diplomacy Manager**: Opens a multi-character diplomacy tool for relations, treaties, wars, and family actions.
- **Artifact Creator**: Opens artifact creation and artifact list tools for a selected character.
- **Cultural Editor**: Opens culture overview, pillar, tradition, innovation, and conversion tools.
- **Faith Editor**: Opens faith doctrine and tenet editing tools.
- **Clear All Pins**: Clears pinned characters and pinned-title state.
- **Test Window**: Test/debug utility currently used to create/load a pinned trait list.
- **Debug Mode**: Runs the `debug_mode` console command. This disables achievements.

## 2. Character Interactions

### Enabling the Interaction Set

Before most Divine Intervention character interactions appear, use the **(DI) Interactions On** character interaction. This sets the internal cheat-menu flag for the player.

After it is enabled, **(DI) Interactions Off** becomes available and hides the expanded DI interaction set again.

### Pinning Targets

**(DI) Pin Characters for Edit** adds characters to the mod's pinned-character list. The selected option controls who is pinned:

- Pin only the selected character.
- Pin all vassals.
- Pin all courtiers.
- Pin all councillors.
- Pin all members of the selected character's house.
- Pin all members of the selected character's dynasty.
- Pin all lovers and soulmates.
- Pin all members of the selected character's house bloc/confederation.
- Pin all close family members.
- Pin all extended family members.
- Pin all living members of the selected character's faith.
- Pin all living members of the selected character's culture.

**(DI) Pin Titles for Edit** adds titles to the Title Manager. It can pin:

- All titles personally held by the selected character.
- All vassal titles.
- All sub-realm titles.
- All realm titles.

### Character Identity and Player Control

- **Switch Character**: Switches the player to the selected AI character.
- **Change Name**: Opens a rename event for the selected character.
- **Convert Religion**: Converts the selected character to the player's faith.
- **Convert Culture**: Converts the selected character to the player's culture.
- **Change Dynasty**: Moves the selected character into the player's house.
- **Change House Name**: Opens an event to rename the selected character's house.
- **Make House Head**: Makes the selected character the head of their house.
- **Create Cadet Branch**: Creates a cadet branch for the selected character.
- **Change Weight**: Adds or removes character weight.
- **Toggle Showing Menu Button**: Hides or restores the skull menu button.
- **Reset Story Variables**: Resets the mod's internal menu variables if windows or options misbehave.

### Religion, Culture, Realm, and Government

- **Change Cultural Acceptance**: Increases or decreases cultural acceptance between the player's culture and the selected character's culture.
- **Learn Language**: Learns the selected character's language.
- **Change Every County**: Applies county-wide effects in the selected character's sub-realm: max control, max development, convert county faith, or convert county culture.
- **Change Government**: Converts the selected character's government to feudal, clan, tribal, administrative, republic, theocracy, or full feudal/clan/tribal variants.
- **Change Government Extended**: Adds DLC/expanded government types such as nomad, landless adventurer, herder, celestial, Japanese administrative, Japanese feudal, Wanua, Mandala, steppe administrative, and meritocratic.
- **Change Succession**: Sets succession to primogeniture or ultimogeniture.

### Family, Marriage, and Pregnancy

- **Arrange Marriage**: Opens a marriage interaction using the selected character as a candidate. It supports normal CK3 marriage options such as matrilineal marriage, hooks, grand wedding promises, piety/influence options where available, and related acceptance tools.
- **Break Betrothal**: Breaks the selected character's betrothal.
- **Force Divorce**: Divorces the selected character.
- **Designate Heir**: Sets the selected character as the player's heir.
- **Adopt**: Adopts the selected character as the player's child and changes them to the player's dynasty.
- **Disown**: Makes the selected character lowborn and removes them from succession.
- **Remove Child**: Removes the selected character as the player's child.
- **Add Concubine**: Makes the selected character the player's concubine.
- **Impregnate**: Starts a pregnancy between the player and selected character. Options include one child, twins, triplets, or spouse-attributed versions of those pregnancies.
- **Sleep With**: Triggers a sex interaction event.
- **Contraceptive**: Makes the selected character unable to have children.
- **End Pregnancy**: Ends the selected character's pregnancy.
- **Take Hostage**: Takes the selected character as hostage.
- **Release Hostage**: Releases a hostage.

### Opinions, Relationships, Hooks, and Secrets

- **Change Opinion**: Sets the selected character's opinion toward the player to love, like, dislike, or hate.
- **Make Friend/Rival/Lover**: Adds or removes relationship states. Supported states are potential friend, potential rival, potential lover, friend, rival, lover, best friend, nemesis, soulmate, bully, and victim.
- **Add Hook**: Adds a weak hook, strong hook, or loyalty hook on the selected character.
- **Remove Hook**: Removes the player's hook on the selected character.
- **Add Secrets**: Adds random, every, incest, deviant, cannibal, non-believer, or homosexual secrets.
- **Reveal Secrets**: Reveals random or every secret.
- **Remove Secrets**: Removes random, every, incest, deviant, cannibal, non-believer, or homosexual secrets.
- **Antagonize Court**: Applies large negative opinion toward the selected character from vassals, courtiers/guests, present family, or all of those groups.

### War, Title, Vassal, and Realm Actions

- **Modify Vassal Contract**: Opens vassal contract modification with normal restrictions bypassed. There are versions for modifying a vassal's contract and for modifying the player's contract with their liege.
- **Claim Title**: Opens a title selection menu for claiming a title held by the selected character.
- **Take Title**: Opens a title selection menu to take one of the selected character's titles.
- **Take All Titles**: Takes the selected character's personal titles or sub-realm titles. Only county-tier and above are considered.
- **Remove Claims On Me**: Removes the selected character's claims on the player.
- **Remove All Claims**: Removes all removable claims the selected character has.
- **Vassalize**: Makes the selected character the player's vassal when government and tier rules allow it.
- **Make Independent**: Makes the selected character independent.
- **Make Tributary**: Makes the selected character a tributary.
- **Add to Court/Add to Camp**: Forces the selected character to join the player's court or camp.
- **End Wars**: Ends the selected character's wars using options such as white peace all wars, lose all wars, win all wars, lose wars to player, white peace with player, or white peace with player vassals.

### Health, Death, Imprisonment, and Flags

- **Murder**: Kills the selected character, with options for random slayer, no slayer, or player/actor slayer.
- **Imprison**: Imprisons the selected character.
- **Excommunicate**: Excommunicates the selected character.
- **Remove Excommunicated**: Removes excommunication.
- **Commit Suicide**: Makes the player character commit suicide.
- **Abdicate**: Abdication interaction hook.
- **Permanent Health**: Toggles a flag that yearly removes bad health flags, modifiers, and traits, similar to the Character Editor's Eliminate Health Issues present.
- **Add Character Flags**: Adds flags such as used lifetime invasion, declared major religious war, and conqueror.
- **Remove Character Flags**: Removes those same flags.

### Diarchy and Power Sharing

- **Start Diarchy**: Starts a regency/diarchy for the selected character. Options allow the player or an NPC to become regent.
- **End Diarchy**: Ends the selected character's regency/diarchy.
- **Swing Scales**: Sets diarchy power scales to 0, 50, or 100 power for the player or NPC side.

### Artifacts, Inspirations, Legends, Travel, and Schemes

- **Take Artifact**: Takes an artifact from the selected character, with options such as giving it to the player or a random neighbor depending on context.
- **Inspire Inspiration**: Gives the selected character an inspiration. Types include weapon, armor, book, weaver, adventure, artisan, smith, and alchemy.
- **Sponsor Inspiration**: Sponsors the selected character's inspiration.
- **Spawn Legend**: Creates a heroic, holy, or legitimizing legend for the selected character.
- **Make Laamp**: Converts/deposes the character into a landless adventurer setup.
- **Move Domicile**: Moves the player's domicile to the selected character's capital province, optionally using travel if the player is a landless adventurer.
- **Populate Contracts**: Populates the selected location with contracts.
- **Infinite Schemes**: Adds or clears modifiers for infinite hostile, contract, personal, or all schemes.
- **Buff Schemes**: Changes schemes owned by the selected character: clear opportunities, add one or many opportunities, add agent slots that improve success chance/growth/max chance/speed/secrecy, set progress to one day, set progress to half, or reset progress.

## 3. GUI: Character Editor

Open the skull button menu, then select **Character Editor**.

The Character Editor acts on the primary edited character by default. The **Pinned** checkbox changes editor actions to affect pinned characters, allowing the same trait, modifier, skill, culture, religion, or present operation to be applied broadly.

### Presents Tab

Presents are quick bundled effects that help or harm edited characters.

- **Lifestyle Presents**: Adds or removes complete lifestyle perk sets and lifestyle completion traits/modifiers.
- **Health Presents**: Eliminate health issues, add or remove good genes, add or remove bad genes, lock or unlock stress, lock or unlock tyranny, and lock or unlock dread.
- **Trait Presents**: Randomize personality, clear personality, add/remove special mod traits, add/remove commander traits, add/remove all education traits, boost education, add/remove aggressive personality traits, add/remove timid personality traits, correct negative personality traits into broadly positive alternatives, make characters giant, make characters dwarf/midget, or make characters ghostly/albino-looking.
- **Law Presents**: Apply gender equality, invert gender norms, apply female-dominated laws/doctrines, apply male-dominated laws/doctrines, or set the player as temporal head of faith.

### Skills Tab

Allows direct editing of the six character skills:

- Diplomacy
- Martial
- Stewardship
- Intrigue
- Learning
- Prowess

Each skill can be increased or decreased by the current increment value.

### Perk Points Tab

Adds or removes perk points for:

- Diplomacy
- Martial
- Stewardship
- Intrigue
- Learning
- Wandering, where supported

It also supports finishing or clearing individual lifestyle trees, and finishing or clearing all lifestyle trees.

### Modifiers Tab

Adds or removes modifiers from edited characters. Modifiers stack, so repeated clicks apply repeated instances. There are controls for negative variants, multiplier variants, and the modifier increment value.

Modifier categories include:

- Prestige
- Piety
- Income
- Opinion
- Health
- Intrigue
- Authority
- Provincial
- Governing
- Military
- Learning
- Men-at-Arms
- Custom Mods

The custom modifier list includes Space Marines, Contraceptive, Immune to Schemes, Ultra Build, Extra Building Slots, One Building Slot, Extra Domain Limit, Money Printer, Permanent Health, Trait XP Boost, Commander Trait XP Boost, Godlike Inheritance, True Rulers, Plague Doctor, Imperial March, Dread Lord, Lifestyle Mastery, Travel Speed, Travel Safety, Legend Spread, Prestige Printer, Piety Printer, Everybody Loves Me, Full Stomachs, Meritorious, and Legitimacy Locked.

There is also a **Clear all modifiers** action that removes mod-added modifiers from all pinned characters.

### Traits Tab

Adds, removes, pins, and tracks traits. Left-click adds a trait, right-click removes it. Trait XP buttons can add or remove trait XP where the trait supports XP.

Trait categories include:

- Physical
- Education
- Commander
- Lifestyle
- Personality
- Fame
- Other
- Tracked
- Pinned

The mod also adds custom traits: NNN Challenger, Divine Builder, Watch Spiff, Lawyer Army, Stat Boost, 100 Stat Man, and Immortal. Immortal stops aging and death from old age.

The trait tab of the character editor can be right-clicked into a larger movable view.

### Sexuality Tab

Sets edited characters to:

- Homosexual
- Heterosexual
- Bisexual
- Asexual

### Culture Tab

Converts edited characters to another culture. It includes quick actions to change pinned characters to the player's culture and to convert pinned characters' counties to the player's culture.

### Religion Tab

Converts edited characters to another faith. It includes quick actions to change pinned characters to the player's faith and to convert pinned characters' counties to the player's faith.

## 4. GUI: Pinned Characters

Open the skull button menu, then select **Pinned Characters**.

This window lists the characters pinned through character interactions or through the mod's pin helpers.

Major features:

- View pinned characters in compact or expanded view.
- Unpin individual characters.
- Pin all living characters in the game.
- Import the base game's pinned character list into the mod's pinned list.
- Set and view a primary pinned character.
- Adjust the global increment used by the currency add/remove actions.
- Review age, diplomacy, martial, stewardship, intrigue, learning, prowess, gold, prestige, piety, dynasty prestige, influence, provisions, herd, barter goods, treasury, and merit level.
- Add or remove gold, prestige, piety, dynasty prestige, influence, provisions, herd, barter goods, treasury, and merit level.
- Add or remove the primary pinned character's skills.
- Change a pinned character's culture or religion through selector windows.
- Take titles from pinned characters through title click actions.
- Access WIP execute, house arrest, and imprison controls.

## 5. GUI: Title Manager

Open the skull button menu, then select **Title Manager**. Titles are normally loaded by using the **(DI) Pin Titles for Edit** character interaction first.

### Title List and Filters

The manager tracks pinned titles and selected titles separately. Selected titles are the action target for most operations.

Available organization/filtering features include:

- Toggle all selected titles.
- Clear all pinned titles.
- Unpin selected titles.
- Pin titles of all pinned characters.
- Sort by rank.
- Select or deselect empires, kingdoms, duchies, and counties.
- Toggle visibility/filter modes, including capital, castle, temple, city, tribe, nomad, herder, temple citadel, and unheld checks.
- Filter by special title groups such as hegemony, empire, kingdom, duchy, county, and pinned-character titles.

### Quick Actions Tab

Applies direct title actions:

- Claim selected titles.
- Take selected titles.
- Destroy selected titles.
- Create de jure liege titles above selected titles.
- Create de jure vassal titles below selected titles.
- Create the entire de jure tree above and below selected titles.

### Conversion Tab

Converts selected or pinned title data:

- Convert title religion using a faith picker.
- Convert title culture using a culture picker.
- Convert selected titles to a chosen de jure title.
- Choose whether actions prioritize selected titles or the full pinned-title list.

### Province Manager Tab

Works on provinces/holdings belonging to selected titles:

- Load and filter province lists.
- Select action provinces with checkboxes.
- Make a barony the county capital where valid.
- Remove holdings, except protected county capitals.
- Add building slots. This is warned as irreversible.
- Set holding type after choosing a holding type.
- Remove buildings.
- Max all building upgrades.
- Let AI generate/upgrade buildings.
- Construct a specific building chain.

Building construction uses a level selector and supports left-click build, right-click destroy behavior. Building categories are based on the building files within the game/mod files. 

## 6. GUI: Character Spawner

Open the skull button menu, then select **Character Spawner**.

The spawner creates characters related to a selected character. It has global options for:

- Female
- No traits
- 100 Stat Man
- Good Traits
- Immortal
- Spawn age
- Spawn count

### Family Tab

Creates family members:

- **Parent**: Spawns one parent for the selected character. Parent replacement can have family side effects.
- **Child**: Spawns children. Multiple children spawned at once are treated as twins.
- **Sibling**: Spawns siblings with the same parents. Multiple siblings spawned at once are treated as twins.
- **Spouse**: Spawns one spouse for the selected character.

### Councillors Tab

Spawns court councillors:

- Marshal
- Chancellor
- Steward
- Spymaster
- Chaplain

### Court Tab

Spawns court/camp characters:

- Commander
- Knight
- Courtier with generated house
- Lowborn courtier without a house

It also supports spawning court-position characters, including Court Physician, Cultural Emissary, Keeper of Swans, Chief Qadi, Garuda, Court Gardener, Chief Eunuch, Lady in Waiting, Antiquarian, Court Tutor, Food Taster, Master of Horse, Master of Hunt, Royal Architect, High Almoner, Seneschal, Cupbearer, Court Jester, Court Poet, Court Musician, Bodyguard, Champion, Executioner, and Artificer.

Dynamic court-position generation is grouped by county, duchy, kingdom, empire or greater, landless adventurer, and other positions.

## 7. GUI: Army Spawner

Open the skull button menu, then select **Army Spawner**.

This window spawns men-at-arms or special units for the player. It includes:

- A count increment controlling how many units to spawn.
- Lists of men-at-arms by type.
- An **Other** category for nonstandard/special units.
- A warning that spawned special-unit levies can affect the military screen's levy balance until those units die off.

## 8. GUI: Diplomacy Manager

Open the skull button menu, then select **Diplomacy Manager**.

The manager works with a primary, secondary, and tertiary character. Characters can be selected from pinned characters and cleared individually.

### Relations Tab

Controls relationship states between selected characters:

- Potential friend
- Potential rival
- Potential lover
- Friend
- Rival
- Lover
- Best friend
- Nemesis
- Soulmate
- Crush
- Bully
- Victim

It can reset or apply selected relationship states between the primary and secondary character, between the primary character and all pinned characters, or between all pinned characters.

### Treaties Tab

Controls diplomatic bindings:

- Form or break treaties between primary and secondary characters.
- Form or break alliances between primary and secondary characters.
- Vassalize the secondary character under the primary character when the title-tier condition is valid.
- Take selected titles for the primary character.
- Make every pinned character form or break a treaty with the primary character.
- Make every pinned character form or break an alliance with the primary character.
- Make every pinned character form or break treaties/alliances with every other pinned character.
- Toggle whether generated treaties are permanent.

### Wars Tab

Controls war actions:

- Select a casus belli.
- Declare war between primary and secondary characters.
- Use selected pinned titles as war targets where the casus belli supports title targets.
- End the war between primary and secondary characters in white peace.
- Use bulk pinned-character war actions such as all declare war, all end war, and every pinned wars.

The available casus belli window currently includes County Conquest, described as a debug war CB.

### Family Tab

Controls family and marriage links:

- Adopt one character into another's family.
- Change a character's house.
- Create a cadet branch.
- Start a pregnancy.
- Force pregnancy gender to male or female.
- Set or reset real father.
- Marry.
- Marry matrilineally.
- Divorce.
- Arrange betrothal.
- Arrange matrilineal betrothal.
- Break betrothal.
- Make characters siblings.

## 9. GUI: Artifact Creator

Open the skull button menu, then select **Artifact Creator**.

This window has a selected character, artifact creation controls, and an artifact list.

### Creation

Artifact creation includes dropdowns for:

- Category
- Subtype
- Quality

Quality options are Common, Masterwork, Famed, and Illustrious.

Artifact categories include pedestal, furniture, ornament, alchemy, armor, books, regalia, throne, tournament, trinkets, and weapons.

Subtypes include many artifact shapes and slots such as animal hides, skulls, trinkets, armor variants, axe, bow, book, brooch, cabinet, chest, chronicle, crossbow, dagger, elixir, goblet, hammer, helmet, journal, longbow, mace, necklace, panacea, philosopher's stone, plate, regalia, ring, scientific apparatus, sculpture, seal of investiture, spear, sword, tapestry, throne, tournament favor, urn, wall icons/shields, and other display variants.

### Artifact List

The artifact list loads artifacts for the selected character and supports:

- Viewing the artifact list.
- Taking artifacts.
- Destroying artifacts.

## 10. GUI: Cultural Editor

Open the skull button menu, then select **Cultural Editor**.

The editor works with a **Culture to Edit** character and a **Culture to Copy** character.

### Overview and Pillars

The culture overview exposes culture pillars and related editors:

- Ethos
- Heritage
- Martial Customs
- Language

It also shows traditions and includes controls to open vanilla hybridization and divergence windows, edit/replace traditions, and view all traditions.

### Innovations

The innovations view supports:

- All innovations view.
- Innovations by era.
- Add all innovations.
- Remove all innovations.
- Add or remove Tribal innovations.
- Add or remove Early Medieval innovations.
- Add or remove High Medieval innovations.
- Add or remove Late Medieval innovations.

### Conversion

Culture conversion is divided into people, counties, sub-realm, and realm tools:

- Convert selected character to the copy culture.
- Convert all pinned characters to the copy culture.
- Convert all pinned characters to player culture.
- Convert every courtier of Culture to Edit to Culture to Copy.
- Convert every vassal of Culture to Edit to Culture to Copy.
- Convert counties of Culture to Edit to Culture to Copy.
- Convert pinned characters' counties to Culture to Copy.
- Convert pinned characters' counties to player culture.
- Convert pinned characters' counties to their own cultures.
- Convert an entire realm to Culture to Copy.
- Convert all pinned characters' realms to Culture to Copy.
- Convert all pinned characters' realms to player culture.
- Quick convert the player realm to player culture.
- Convert a sub-realm to Culture to Copy.
- Convert all pinned sub-realms to Culture to Copy.
- Convert all pinned sub-realms to player culture.
- Quick convert the player sub-realm to player culture.

## 11. GUI: Faith Editor

Open the skull button menu, then select **Faith Editor**.

The Faith Editor displays the selected faith's beliefs and lets the user change doctrine groups.

Features include:

- View current core tenets.
- Replace existing tenets/doctrines by selecting a replacement doctrine.
- Add additional tenets beyond the normal amount.
- Right-click/remove doctrines where supported by the scripted GUI.
- Browse selectable doctrines grouped as core tenets, main doctrines, marriage doctrines, crime doctrines, clergy doctrines, and other doctrines.

## 12. GUI: Event Manager

Open the skull button menu, then select **Event Manager** in debug mode.

This is labeled as proof of concept/placeholder. Current visible event categories include:

- Example Event
- Pregnancy
- Harm

