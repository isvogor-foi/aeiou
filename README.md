# Rise of Magic

A 3D steampunk-magic real-time strategy game for Godot 4 (typed GDScript).
The **Aetheric Monarchy** faces the **Umbral Covenant** across six ages. The Monarchy is an alternate Habsburg empire where Aether powers steam and the arts of alchemy, and its motto is A.E.I.O.U. See `docs/aetheric_monarchy.md`.

## Running

```sh
tools/godot --path .                                   # play (title screen)
tools/godot --path . -e                                # open in the editor
tools/godot --headless --path . -s tests/run_tests.gd  # simulation tests (exit code = failures)
tools/godot --headless --path . -s tests/bench_battle.gd  # 100 v 100 performance benchmark
tools/godot --headless --path . -s tests/soak_ai.gd -- 40 77 hard normal islands  # AI vs AI: minutes, seed, difficulties, map
tools/godot --path . -s tests/screenshot.gd -- /some/dir  # scripted visual check, saves PNGs
```

`tools/godot` is the official Godot 4.7.2 Linux binary. It is not checked in;
download it from godotengine.org if it's missing.

## Controls

| Input | Action |
|---|---|
| Left click / drag | Select (Shift adds; double-click selects all of that type on screen) |
| Right click | Smart command: move, attack, gather, help build; on buildings, set rally point |
| Shift + command | Queue the order |
| Command card hotkeys | Shown on each button (e.g. `Q` train worker, `B` barracks, `A` attack-move, `S` stop) |
| Ctrl+1–9 / 1–9 | Set / recall control group (double-tap to jump to it) |
| `.` | Cycle idle workers |
| `H` | Select home city |
| `Space` | Centre on selection |
| Arrows, screen edges | Scroll |
| Mouse wheel | Zoom |
| Middle-drag, `[` / `]`, Alt+Q / Alt+E | Rotate the camera a quarter turn (90°) at a time (`Backspace` resets it) |
| `P` | Pause |
| `+` / `-` | Game speed |
| `F5` / `F9` | Quick-save / quick-load |
| `Esc` (nothing selected) or `F10` | Game menu: save to a slot, load, main menu |
| `Ctrl+F9` or ★ Cheats (top right) | Reveal map; the Cheats menu also has infinite resources |

## Layout

```
data/     All content as JSON: units, buildings, resources, ages, factions, damage matrix, rules, 3D visuals
sim/      Deterministic fixed-tick simulation (20 Hz). No nodes; drives everything through World.issue()
mapgen/   Seeded, point-symmetric two-player map generator
view3d/   3D rendering: heightfield terrain + shaders, animated models, fog pass, RTS camera, input (game_view_3d.gd)
assets/   CC0 KayKit models (see assets/CREDITS.md); assets/recolor/ holds uniform recolours from devtools/recolor.py
docs/     Design notes
ai/       Computer opponent (plays through World.issue(), tuned by data/ai.json)
ui/       HUD, minimap, main menu
tests/    Headless tests, benchmark, screenshot driver
```

Rules of thumb:
- Stats live in `data/`, never in code.
- The simulation never touches nodes.
- Every gameplay change, whether from the player, the AI or later the tutorial, is a command dict passed to `World.issue()`.

## Status

**Phase 1 (core loop)** is done:
- Procedural maps, fog of war
- Gathering four resources, training, construction
- Damage-matrix combat
- Warcraft II-style controls and minimap

**Phase 2 (Rise of Nations systems)** is done:
- **Territory:** cities project borders. You can only build inside your own borders, and units in enemy land take attrition (Supply Wagon / Bone Cart units prevent it).
- **Cities:**
  - Workers found new cities in neutral land, up to 1 + current age, at least 12 tiles apart.
  - A city at 0 HP is captured if you have more troops near it than the defender. Otherwise it holds at 1 HP.
  - Losing all cities means defeat.
- **Gather caps:** per-resource income limits, shown in the top bar as `+rate/cap`.
- **Library:** Cameralism (economy), Fortification and Medicine, 6 levels each. Level N needs age N. Soldier upgrades come from the military buildings (see Phase 8 fixes).
- **Ages:** advance at a city through all six ages. Age raises the city limit and unlocks content.

**3D view:**
- Gently rolling terrain, lakes, forests, and borders drawn on the ground.
- Animated soldiers and monsters: one Quaternius figure dressed in code (dieselpunk Monarchy, necro-industrial Covenant, golems and colossi), cavalry on shaped horses in barding.
- Steam and necro machines, wagons and walkers built from primitives (view3d/machines.gd, view3d/mounts.gd).
- Procedural steampunk buildings in team colours, construction scaffolding, and rubble when buildings are destroyed.
- Fog of war done as a depth-based screen pass.

**Phase 3 (computer opponent)** is done:
- Pick Easy, Normal or Hard on the title screen.
- **Economy:** it trains workers and spreads them across resources to fill its gather caps, shifting away from anything it's stockpiling. It builds housing, Herb Gardens, barracks and a library.
- **Growth:** it researches in a per-faction order, saves up for age-ups and founds new cities beside unclaimed resources.
- **War:**
  - It defends its cities against invaders.
  - It attacks in growing waves and retreats when a wave is broken.
  - It moves on to the next city after a capture.
- **Faction styles:** the Covenant raids early with Reavers. The Monarchy builds its economy first and attacks later in bigger waves.
- **Difficulty:**
  - Easy and Normal play by your rules (fog of war, same economy). Easy is slower and attacks with smaller waves.
  - Hard gathers 25% faster (caps included), sees the whole map and attacks sooner.
- **New building, the Herb Garden:** endless herbs, tended by up to 2 workers.

**Phase 4 (Ages 1–3 content)** is done:
- **New units:**

  | Faction | Ranged | Caster | Elite (Age 3) |
  |---|---|---|---|
  | Monarchy | Jäger | Field Alchemist: Field Dressing, Aether Ward | Kürassier: Charge |
  | Covenant | Bonebow | Necromancer: Life Drain, Raise Dead | Grave Brute: Cleave |

- **New buildings:** Schießstand / Bone Range, Laboratorium / Ossuary, and Festungsturm / Bone Spire defense towers.
- **Heroes:** one per player from Age 3, trained at a city. A fallen hero can be revived (60s).
  - **Rudolf II:** Alchemic Fire, Imperial Aegis, and an aura that cuts damage taken by 20%.
  - **Shadow Sovereign:** Soul Siphon, Summon Horde, and a 15% life-steal aura.
- **Abilities (Aether arts and necromancy):**
  - Each one costs Aether and has a cooldown. Ability data lives in `data/abilities.json`.
  - Field Dressing and Life Drain cast themselves by default.
  - Ability hotkeys are D and F, followed by a click on the target. Right-click an ability button to toggle autocast (`*`).
- **AI:** it builds the new buildings, fields the full roster, autocasts every ability, trains its hero, reaches distant resources and favours founding cities near gold.

**Phase 5 (air and naval)** is done:
- **Map types:** pick Inland (lakes), Coastal (a shared central sea) or Islands (a strait splits the map) on the title screen.
  - On water maps every start has a bay to the open water.
  - Fish shoals are a new renewable-ish source of herbs.
- **Air units:**
  - Monarchy: Kress Flyer (Age 2) and Double Eagle (Age 3), from the Adlerhorst.
  - Covenant: Bat Swarm (Age 2) and Bone Drake (Age 3), from the Roost.
  - Flyers ignore terrain. Melee can't reach them; ranged units, towers and other flyers can.
  - Jäger, Bonebows and Double Eagles deal +50% to air.
- **Naval units** (from the Docks, built on the shore in Age 2):
  - **Fishing Skiff:** lands herbs at the docks.
  - **Transport:** holds 8 population and costs none. Right-click it with troops to board; select it and right-click a shore to unload.
  - **Warship:** +50% vs ships, and it shells the shore.
- **Fog of war:** explored ground now stays visible (`explored_stays_visible` in `data/rules.json`).
- **AI:** it builds docks wherever there's a usable shore, fishes, fields flyers and warships, and ferries attack waves across water on Islands maps.
- **Models:** ships, flyers, the pier and fish shoals are procedural low-poly models (`view3d/procedural.gd`). The Kress Flyer is a KayKit figure under an Aether glider.

**Phase 5.5 (Aetheric Monarchy re-theme)** is done:
- **The original light faction is now the Aetheric Monarchy**, in imperial gold.
  - **Renamed resources:** Thaler, Timber, Provisions and Aether.
  - **Habsburg ages:** the Margraves through the Aether Monarchy.
  - **Re-themed roster:** Settler, Grenadier, Aether Musketeer, Jäger, Field Alchemist, Kürassier, Kress Flyer, Double Eagle, and the hero Rudolf II.
  - **Uniforms:** dieselpunk field kit: steel helmets, gas masks with glowing lenses, trench greatcoats, armour plates and Aether tanks.
- **Crown lands:** the capital is Austria (with the Tyrol). Proclaim each new city Croatia, Carniola, Bohemia, Galicia or Transylvania (the buttons are on the city card). Each land unlocks a regional unit:
  - **Standschütze** (Austria): long-range marksman with +2 range and +30% damage from high ground.
  - **Grenzer** (Croatia): a farmer-soldier that gathers and shoots, and fights harder at home.
  - **Quicksilver Bombardier** (Carniola): lobs Idrija mercury bombs that splash and leave a toxic cloud.
  - **Hussite War Wagon** (Bohemia): carries 4 troops, and deploys into a Wagenburg they fire from.
  - **Uhlan** (Galicia): fast lancer whose charge strikes for +150%.
  - **Vampire Hunter** (Transylvania): silver shot and phosphor, +60% against Covenant beasts and warded dead.
- **Viribus Unitis:** mixing troops from several crown lands gives up to +15% damage.
- **Heraldry:**
  - Waving flags on every building: the imperial black double-headed eagle on gold for the Monarchy, and a skull banner for the Covenant.
  - Cities also fly their crown land's flag: Austria red-white-red, the Croatian chequerboard, Bohemia's white over red with the lion, or the red Tyrolean eagle.
  - Solid team-colour borders over cobbled city ground, Schönbrunn-yellow façades, and a faction-coloured HUD with the flag in the top bar.
  - A title-screen emblem with the A·E·I·O·U motto.
  - Flags are painted in code (`view3d/flags.gd`).
- **Elevation now matters in gameplay:** hills are part of the simulation, mirrored for fairness.
- **AI:** it proclaims lands and uses Grenzer as workers. It fields Standschützen and War Wagons, though it won't garrison its wagons.

**Phase 6 (Ages 4–6)** is done:
- **Coal:** a fifth resource, mined from coal seams. One sits just beyond each start's first border. It powers the steam units and buildings from Age 4.
- **Monarchy units:**
  - Fabrik: Steam Walker (rotary gun) and Škoda Mortar (sets up, has a minimum range, splashes).
  - Kaiserjäger with the Girandoni air rifle (6 shots, then a reload).
  - Lohner Aethership: an air bomber that carries 6 troops.
  - Tegetthoff Ironclad, with a Ram ability.
  - Aether Colossus: one at a time, with a +15% aura.
- **Covenant units:**
  - Abomination (Hook ability) and Ghoul Rider.
  - Plague Catapult, which leaves poison clouds.
  - Shadow Wyrm.
  - Ghost Ship, invisible while it keeps still.
  - Lich (Grave Chill, Mass Raise).
  - Bone Colossus, whose fear aura lowers enemy damage.
- **Dark Pacts:** the Covenant's answer to crown lands. Blood unlocks the Vampire (life-steal), Bone the Bone Golem, Shadow the Wraith (stealth).
- **Heroes:** choose 1 of 3. Your first hero stays your hero for the match.
  - Monarchy: Rudolf II, Prince Eugene (siege aura, Bombardment), Maria Theresa (gathering aura, Theresian Reform, Inoculation).
  - Covenant: the Shadow Sovereign, Morvana the Blood Countess, the Bone Herald.
- **Wonders** (on the worker's **Wonders** page, one of each):
  - Monarchy: Prague Orloj (faster research), St. Stephen's and the Pummerin (enemies weaker in your land), Semmering Railway (faster units at home), Hofburg Treasury (holds relics, +Thaler).
  - Covenant: Obsidian Spire and the Great Ossuary.
- **New ways to win:**
  - **Territory:** hold 70% of the land for 5 minutes.
  - **Wonders:** hold 3 for 5 minutes.
  - **A.E.I.O.U.:** five relics appear when someone reaches Age 5 (Imperial Crown, Holy Lance, Agate Bowl, Unicorn Horn, Imperial Orb). Soldiers carry them (right-click) to your Treasury or Ossuary. Hold all five for 3 minutes.
  - The countdowns show under the top bar.

**Phase 6.5 (loyalty and federation)** is done:
- **City loyalty** (the Covenant calls it **Dread**) runs from 0 to 100. Each city drifts toward a target, and the city panel explains it factor by factor.
  - **Lowers it:** distance from the capital, too many cities, a recent conquest, and war-weariness from soldiers lost. Enemy soldiers inside the city's borders also drain it directly.
  - **Raises it:** a garrison, a library or wonder nearby, a hero visiting, peace, and Medicine research.
- **Rebellion:** you're warned at 25. At 0 the city revolts to **Hungary** with a militia, and anyone can retake it. If the capital falls, your oldest city becomes the new capital.
- **Federal Charter** (Monarchy, Age of the Congress), granted from the city card:
  - The city's loyalty never drops below 50, and its crown-land bonus grows by half.
  - It passes on 20% less income.
  - You get one charter per city besides the capital, and can't revoke it for 3 minutes.
- **Blood Tithe** (Covenant): sacrifice the nearest soldier to restore 25 Dread, with a 60s cooldown per city.
- **AI:** it garrisons shaky cities, grants charters and pays tithes.

**Phase 7 (the game around the game)** is done:
- **Main menu:** Skirmish, Tutorial, Campaign, Load Game, Settings.
- **Skirmish setup:** map type and size (64/96/128), starting age (1 to 4), resources (Standard, High, Deathmatch), game speed, visibility (black shroud, explored or revealed) and which alternative victories count.
- **Save and load:** F5/F9 quick-save, five named slots in the game menu (Esc or F10), and an autosave every 5 game minutes. Saves hold the whole match, including the AI and any scenario, and live in `user://saves`.
- **Audio:**
  - Sound effects are synthesised in code (`audio/sfx.gd`): musket cracks, cannon, clanging steel, arcane whooshes, curses, fire, construction, fanfares, drums.
  - Music is public domain (see `assets/CREDITS.md`): Haydn's *Kaiserhymne* in the menu, the *Blue Danube* in peacetime and the *Radetzky March* when your troops are fighting.
  - Volumes are in Settings.
- **Tutorial:** gather, build a Kaserne, train soldiers, advance an age, capture a city.
- **Campaign, "Sarajevo 1914: the shot that missed"** (each mission unlocks the next):
  1. *The Shot That Missed:* escort Archduke Franz Ferdinand past four ambushes to the Sarajevo Town Hall.
  2. *The Siege of Vienna:* hold the Hofburg for ten minutes against growing Covenant waves.
  3. *Viribus Unitis:* start in the Age of the Congress, proclaim the crown lands and win by the A.E.I.O.U. relics.
- Scenarios are small scripts in `scenarios/` (`setup()` plus a once-a-second `update()`), with their state kept in the world so it saves with the match.

**After Phase 7 (playtest feedback):**
- **Menus:** title screen with branding on the left and one framed panel per page. Main menu with Continue; a two-column skirmish setup; mission cards; a settings page with fullscreen. The theme lives in `ui/menu_theme.gd` and is shared with the pause menu.
- **In-game screen:**
  - Translucent resource pills with icons (top left) and status pills (top right): age, idle workers, speed, ★ Cheats and ☰ menu.
  - The command grid of picture tiles sits bottom left, with the selection panel beside it and the minimap bottom right.
  - Multi-selections show a tile per unit with a health bar. Training and research show a progress bar and picture tiles for the queue.
  - Icons are drawn in code in `ui/hud_icons.gd`.
- **Camera** pitched at 42° (`PITCH_DEG` in `view3d/rts_camera.gd`). Settlers wear Schönbrunn yellow.
- **Borders grow as you build:**
  - Every finished building claims land: 3 tiles, towers 5, wonders 6.
  - A city's radius grows by a quarter tile per building around it, up to +3.
  - The numbers are in `rules.json` under `"borders"`.
- **Soldier upgrades moved to the military buildings:**
  - Each building has a 3-level line (hotkey `U`, e.g. Kaserne: Drill Regulations) giving +10% damage and +10% HP per level, for the troops it trains only.
  - The library keeps Cameralism, Fortification and Medicine (which absorbed Alchemy's population bonus).
  - Different lines can research in parallel in different buildings.
- **Relics** can be stored in any of your cities, not only the treasury wonders.
- **Steampunk buildings** (`view3d/buildings.gd`): every building is built in code from primitives and baked into one mesh per material. Monarchy buildings use ochre stucco and brick, verdigris domes, brass, gas-lit windows, smokestacks, flywheels, Tesla coils and Aether tanks. Covenant buildings use black iron, bone, spires and soul-furnaces. `tests/building_gallery.gd` renders them all.
- **City designs per land:** a city is rebuilt when it proclaims a land:
  - Austria: a Schönbrunn palace with a dome and an Aether mast.
  - Croatia: a frontier fortress.
  - Carniola: an Idrija mine-castle with a headframe.
  - Bohemia: Prague spires and an astronomical clock.
  - Galicia: onion domes with oil derricks.
  - Transylvania: a Saxon fortress-church.
  - Covenant pacts recolour the Citadel.
- **Hungary, the internal enemy:** a third AI side, hostile to everyone, that can't win or lose. After 12 minutes it rises near the map centre with a city, Kaszás scythemen, Honvéd infantry and Hussars, then builds and attacks every side. Cities that revolt join it. Scenarios turn it off (`"hungary": false` in the options).
- **Flags:** the Austrian crown land flies the Austrian Empire's black-over-gold.

**Visual pass (steampunk meets magic):**
- **Characters:**
  - Smooth-subdivided bodies, about 4× the triangles, made by `devtools/subdivide.py`.
  - People and wagons drawn at 75% size.
  - Procedural steampunk kit (`view3d/gear.gd`, each piece baked into one mesh):
    - Monarchy: brass goggles, top hats with cog bands, Aether backpacks with copper pipes, glowing vials and a gauge, brass pauldrons, and Aether staffs.
    - Covenant: soul lanterns, grave packs and iron circlets.
  - No wizard hats, wands or spellbooks remain.
- **Trees:** Quaternius stylized pines and broadleaf trees (CC0), recoloured in code and batched in 16-tile chunks.
- **Buildings:** chimneys with smoke, turning wall cogs, Aether or soul lamps, and pipe runs.
- **Text:** all Potter-like wording is gone. Research levels, ages, the Soul Caller and Alchemic Fire now read as steampunk-meets-magic.
- **Performance:**
  - A 150-unit battle on an Intel Iris Xe laptop at Medium graphics runs at about 46 fps.
  - Distant objects switch to simpler LOD meshes sooner on Medium and Low graphics.

**Roster rework, steam machines, realistic soldiers:**
- **Signature powers:**
  - Hold the Line (Grenadier), Volley (Musketeer), Camouflage (Jäger), Frenzy (Reaver) and Wither (Soul Caller), plus Aether Bomb (Kress Gyrocopter) and Plague Drop (Plague Balloon).
  - The Škoda Siege Crawler and Corpse Crawler set up in 1 second.
  - The Steam Walker splashes fire.
- **New machines:**
  - The **Landpanzer** steam tank (Monarchy) and the **Bone Juggernaut** (Covenant): steel armour (musket fire does 45%) and Full Steam / Soul Furnace (+60% speed and +40% damage for 6 seconds).
  - The detailed procedural models are in `view3d/machines.gd`.
- **Realistic people:**
  - Every soldier, worker and hero uses the Quaternius realistic figure (CC0, 46 animations: aiming, sword, casting, fixing, riding).
  - Uniforms are painted onto the body by bone region, plus hats, coat tails, robes, crossbelts, cuirasses, kit and weapons, merged into one skinned mesh per outfit (`view3d/figure.gd`).
  - Kürassiere now ride.
  - Monsters and giants keep their stylized models.
- **Flags:** the imperial banner is a vector-drawn double-headed eagle (`view3d/imperial_svg.gd`): crowned heads, sword and orb, and the red-white-red breast shield. The Empire bicolour carries the eagle arms.
- **Performance:** a 150-unit battle runs at about 38 fps on an Intel Iris Xe laptop at Medium. The skeletons now dominate the frame.

**Phase 8 (balance and performance)** is partly done.

Performance is finished:
- **Simulation:** the peak tick of a 400-unit battle went from about 25–50 ms (with spikes up to 830 ms) to about 13–16 ms (spikes up to about 58 ms).
  - Connected-region pathfinding, so unreachable goals no longer search the whole map.
  - A per-tick path budget, so big orders spread over a few ticks.
  - Cached approach goals and drop-offs, cheaper enemy scans, and fog that skips units that haven't moved.
- **3D view:**
  - Units use blob shadows only.
  - Animation updates only for units on screen, at 20 Hz in big battles.
  - New **Graphics** setting (Auto, High, Medium, Low). Auto picks Medium on integrated GPUs.
  - On an Intel Iris Xe laptop at Medium: about 29 fps in a 150-unit battle, 13 fps in the 400-unit stress test.
- **Tools:** `tests/profile_sim.gd`, `tests/bench_battle.gd -- <per_side>`, `N=75 tools/godot --path . -s tests/bench_fps.gd`.

**To do (Phase 8, paused):**
1. **Baseline batch.** Run `tests/run_balance.sh <out_dir> 3 6 normal 60` (18 AI-vs-AI games, both sides, all maps), then summarise with `tests/balance_report.py`.
2. **Pacing to 25–35 minutes:**
   - Aether income (cap 0.8/s) makes the late age-ups very slow.
   - AI armies are small (Normal `army_cap` 45; peaks of about 70 per side), and its first wave comes at 5–8 minutes.
   - Age costs and times need checking against these.
3. **Fairness about 50/50:** mirror-test both sides on every map type. The Covenant tends to fall an age behind.
4. **Victories:**
   - Territory (share and hold time): easier now that buildings push borders out.
   - Relics: longer hold, and capturing a city should take its relics.
   - Wonders: costs and hold time against the new pace.
   - The military upgrades (+10% per level) against the pace.
5. **Missions:** re-verify Mission 2 (Vienna) after pacing changes, and play Mission 3 (Viribus Unitis) to the end with a bot.
6. **Performance, optional:** in big crowds, unit separation (about 3.5 ms) and per-unit view sync (about 20 µs per unit) are the next costs.
