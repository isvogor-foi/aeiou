# Roadmap: Ages 7–12 and Campaign 2

The plan for **The Undying Century** (1926–1955): six new ages, new soldiers and machines for both sides, buildings that keep evolving, and six campaign chapters. The story is in [story.md](story.md); how the code fits together is in [technical.md](technical.md).

**How to build it:** first make the engine ready for 12 ages and for units that upgrade, then build the shared art systems, then add **one age at a time together with its chapter** (Age 7 + Chapter 7, then Age 8 + Chapter 8, …). Each age is playable and tested before the next starts. Balance comes last, across the whole ladder.

Sizes: **S** an hour or two, **M** a day, **L** several days.

---

## Phase 0: Finish what's open (before any new content)

- [x] **S** Settle the `main` / `origin/main` split (reset to `origin/main`, or force-push) and commit the pending work.
- [ ] **M** Playtest Campaign 1, chapters 1–6; fix what turns up (Chapter 2's Grave Engine and Chapter 5's Empress are the balance suspects).
- [ ] **L** Phase 8 balance for Ages 1–6 (see the to-do list in technical.md): pacing to 25–35 minutes, 50/50 fairness, victory tuning. Ages 7–12 will be balanced against this baseline, so it should be stable first.

## Phase 1: Foundations for 12 ages (engine, no new content) ✔ done 2026-11-15

**Decided:** engine work before the Ages 1–6 balance pass (that pass now runs just before Phase 4); research extends to 12 levels; refits are automatic on age-up (Phase 2); unfinished ages are hidden until built.

**As built:** ages 7–12 are in `data/ages.json` marked `"wip": true`; `DB.last_age()` is the last finished age; each match keeps its own `World.max_age` (skirmish "Last age", saved with the match; old saves fall back to the data); `--all-ages` on the command line opens the unfinished ages for developers. Library branches have 12 levels, military lines 6 (at ages 1/3/5/7/9/11 or 2/4/6/8/10/12). The AI's per-age tables reuse their last entry past their end; an AI-vs-AI test climbed to Age 12 without errors. Relics (Age 5), charters (Age 5) and Hungary's rise (a timer) need no change: a game that starts at Age 7 simply has them from the start. Research costs above level 6 follow the old growth curve and get tuned in Phase 6.

Most of the simulation already reads the age count from `data/ages.json`. These places assume six:

- [x] **S** `ai/ai_player.gd` `_age_index()` clamps to 0–5; make the per-age tables in `data/ai.json` any length (pad with the last entry).
- [x] **S** `view3d/buildings.gd` `_age_palette` / `_age_dress` stop at Age 6; open them to 12 (the art comes in Phase 3).
- [x] **S** `tests/building_gallery.gd` loops ages 1–6; `tests/run_tests.gd` asserts exactly 6 ages. Read the count from the data instead.
- [x] **M** **Research beyond level 6:** library branches (Cameralism, Fortification, Medicine) and the military lines are 6 levels with "level N needs age N". Decide: extend each to 12 levels, or add new modern branches (e.g. Electrification, Motorisation, Radio). Then update `data/techs.json`, the HUD research tiles and the AI research order.
- [x] **M** **Skirmish age range:** today the menu offers a starting age of 1–4. Add an *ending* age too, with presets: Classic (1–6), Modern (7–12), Full (1–12). A 12-age game must still fit a sensible length.
- [x] **S** Rules tied to ages: relics appear at Age 5 (`relics_spawn_age`), charters at Age 5 (`charter_age`), Hungary's rise. Check each still makes sense in a game that starts at 7.
- [x] **S** Age-up costs and times for 7–12 in `data/ages.json` (placeholders first, tuned in Phase 6).
- [x] **S** Saves: old saves must still load (they never contain ages above 6).
- [x] **M** Tests: a 12-age smoke test (advance through every age; every unit, building and research of every age is reachable for both factions).

## Phase 2: Units that upgrade (the "people upgrade") ✔ done 2026-11-15

**As built:** a unit names its successor with `"upgrades_to"`, and the successor's own `"age"` is when the line moves up. Buildings keep listing a line by its first unit.
- `DB.line_root`, `DB.tier(type, age)` and `DB.line_of` (`sim/db.gd`) answer every "which tier?" question.
- Training (`World._train`) always queues the current tier at its own price; a unit still in training when the age arrives comes out as the new tier.
- Age-ups refit every non-hero soldier of the player at once and for free (`World.refit_units`), keeping id, orders, health share, cooldowns, cargo and control groups; the view rebuilds the model; a "Refitted: …" message names what changed.
- `"limit"` counts the whole line (`World.line_count`); scoped military research follows the line (`Research.trainer_of`).
- HUD: the train tile shows the current tier with the line's hotkey, and the tooltip says what it becomes and when.
- AI: counts its army by line and pays the current tier's price; `army_mix` in `data/ai.json` keeps naming lines by their first unit.
- Scenarios: `tier(w, type_id)` gives the current tier for spawning.
- Tests: the line data rules, and a temporary Musketeer → Test Rifleman line exercising training, refits, queues, prices and limits.

No real lines exist yet: the first ones arrive with Age 7's roster in Phase 4. Veterancy doesn't exist in the game, so there was nothing to carry over.

- [x] **M** **Unit lines in data**
- [x] **M** **Refit on age-up** (automatic, decided 2026-11-15)
- [x] **S** HUD
- [x] **S** AI
- [x] **S** Scenarios
- [x] **S** Tests

## Phase 3: Shared art systems ✔ done 2026-11-15

Each of these is a toolkit that every age then uses. Build and gallery-test each before making content.

### People: uniforms by era (`view3d/figure.gd`)
- [x] **M** Era layer (2026-11-15): an outfit `"id@N"` dresses `id` from Age N on (`Figure.variant`); the view rebuilds figures when an age-up changes what they wear. Variants so far: the Settler (overalls at 7, hard hat at 10), the Thrall (suit and bowler at 7), Franz Ferdinand (field grey, peaked cap, grey moustache at 7), Tesla (grey at 7).
- [x] **M** Monarchy kit for the planned tiers: `rifleman`, `sturmtrupp`, `sanitaeter`, `gebirgsjaeger`, `radio_spotter`, `paratrooper`, `rocket_trooper`, `flame_trooper`, `atom_trooper`, `arctic_trooper`, plus `tank_crew` and `pilot`. New coat styles (tunic, suit, overalls, flight jacket, parka), hats (later helmet, jump helmet, Bergmütze, peaked cap, flying helmet, tanker helmet, fur cap, hard hat, gas hood, radiation hood), webbing, armbands, headphones. The outfit ids are the unit ids Phase 4 should use.
- [x] **M** Concern kit: `debt_bound` (suit, bowler), `tommy_ghoul` (fedora, drum gun), `gas_trooper` (rubber hood, soul sprayer), `wireless_medium` (headphones, radio pack), `frost_dead` (parka, rime and icicles). Armoured abominations already exist (`abomination`).
- [x] **M** Weapons: bolt-action rifle (optional scope), automatic rifle, submachine gun, tommy gun, light machine gun with bipod, Aether rocket tube, binoculars, soul gas sprayer; kits: field radio, medic's bag.
- [x] **S** Animations (2026-11-15): the library has no rifle, SMG or throwing clips; gunners use `Pistol_Shoot` with `Pistol_Idle` (weapon at the ready). Presets in visuals.json `"anim_presets"` (gunner, rifleman, medic with `Fixing_Kneeling`, radio with `Idle_Talking`/`Interact`, worker, caster, officer with `Walk_Formal`); a unit's `"anims"` can name one. `test_animation_names` checks every clip exists. Crouch clips exist (`Crouch_Idle`, `Crouch_Fwd`) if a unit wants them.
- [x] **S** Gallery: `tests/era_gallery.gd` renders every new outfit and the era variants at Ages 1, 7 and 10.

### Vehicles (`view3d/vehicles.gd`, routed through `view3d/machines.gd`)
- [x] **L** Vehicle kit (2026-11-15): wheels that turn with the distance driven (`"roll"`), track belts whose tread scrolls (`"tread"`, a small instance-uniform shader), turrets that swing to the last target and back (`"turret"`), hull rumble while driving (`"rumble"` in visuals.json), exhaust smoke, headlights, seated crew. Moving parts are baked one mesh each; the rest of the vehicle is one mesh per material, as before. `tests/vehicle_gallery.gd` parks and drives them all; `test_vehicle_kit` checks every model.
- [x] **M** Cars and trucks: Austro-Daimler staff car and armoured car, lorry, motorcycle with sidecar, halftrack.
- [x] **M** Tanks: light tank, Porsche heavy tank, Aether rocket truck (walker refits come with their ages).
- [x] **M** Aircraft: biplane, Aether zeppelin, monoplane fighter, jet. Propellers spin (with a blur disc), jets leave contrails that stay behind in the world; planes bank into turns and, with `"circle"` in visuals.json, orbit slowly while idle. (The Lohner Aethership keeps its own model.)
- [x] **M** Concern machines: hearse, corpse-truck, undead panzer, bone halftrack, corpse-zeppelin, bat-plane (flapping membrane wings), wraith jet (soul-green trail).
- [x] **S** Movement feel (2026-11-15): `"accel"` in units.json (seconds to full speed) makes a vehicle pull away at a quarter speed after every stop (simulation, saved); `"turn"` in visuals.json slows how fast the hull swings round (view only; given to the existing wagons, tanks and crawlers). Wide turning circles in the pathfinder were left out: too costly for what they add. Phase 4 vehicles should set both.
- [x] **S** Existing machines on the kit: the Landpanzer (moving tracks, a turning turret) and the Bone Juggernaut (moving bone tracks). The crawlers and wagons keep their baked models.

### Buildings that keep evolving (`view3d/buildings.gd`)
- [x] **L** Ages 7–12 dressing (2026-11-15), cumulative like Ages 1–6 (`_modern_dress` in `view3d/buildings.gd`):
  - 7 Federation: electric globe street lamps with wires to the building, a neon sign over the door in the team colour; electric-white windows.
  - 8 Zeppelins: radio aerials on the roof.
  - 9 Diesel: a concrete side annex with a garage door, fuel tanks in team colours; roofs and trim turn to concrete and steel.
  - 10 Radar: a turning radar dish replaces the Tesla mast; sandbags, a searchlight.
  - 11 Atom: a reactor dome on the annex, hazard stripes; fluorescent windows.
  - 12 Rockets: the annex becomes a glass-and-steel wing; an antenna mast with a red light.
  - The Concern: a green ledger-and-skull sign, séance aerials with soul vials, black iron annex and tanks, a bone radar dish, a crematorium stack with soul smoke, a black-glass wing and a bone spire.
  - Not done: Art Deco façades (tried as pilasters; they stood off the façade on buildings with steps and plinths), mooring masts, flak towers.
  - Known: the side annex sits just outside the building's footprint, so packed buildings can overlap a little at the sides.
- [x] **M** City designs per crown land, modern (2026-11-15): each crown-land city adds a landmark at a back corner from its age: Austria a lattice radio mast (7), Croatia a coastal-artillery bunker (8), Galicia an oil refinery with a flare (8), Carniola a concrete headframe with a turning wheel (9), Bohemia the Škoda works with a chimney (9), Transylvania a floodlight tower (9). The Concern's pact citadels keep only the generic layers.
- [x] **S** `tests/building_gallery.gd` renders ages 1–12 (`-- <out_dir> ages`).

### City life and ambience (`view3d/traffic.gd`, `view3d/ambience.gd`)
- [x] **M** Civilian traffic (2026-11-15): from Age 7 saloon cars, from Age 8 a city bus, and townspeople wander the open ground of cities near the camera, in straight lines between free tiles of the city's own land; the Concern's cities get hearses and dead clerks in bowlers. Only the nearest cities get traffic (Medium: 3 cities, 3 cars, a bus, 6 walkers each; High: 5 cities and more; Low: none). Hidden in the fog; pauses with the game. Not in the simulation. Trams were left out (they need rails).
- [x] **S** Night lighting grows with the ages: gaslight → electric globes (7) → neon signs (7) → fluorescent windows (11) → searchlights (10) (done with the building dressing).
- [x] **S** Soot thickens with industry: half the falling soot until Age 6, rising to double by Age 12.

### Effects and sound
- [x] **M** Effects (2026-11-15, `view3d/effects.gd`): a unit's visuals.json `"shot"` picks its fire: `"burst"` (tracers; `"burst": n` rounds), `"shell"` (a tracer and an explosion), `"rocket"` (a smoking rocket and an explosion), `"flame"`, `"flak"` (black puffs). Explosions flash, ring and smoke. The Aether bomb (a `"bomb"` event: pos, radius) flashes, rings twice, raises a mushroom cloud and leaves a scar decal that cools to a faint lasting glow (view only: lost on reload). Hit events now name the firing unit (`"unit"`). `tests/effects_gallery.gd` shows them all.
- [x] **M** Sound (`audio/sfx.gd`): submachine gun and machine gun bursts, tank gun, rocket, explosion, the Aether bomb, an air-raid siren, radio static with morse pips, an engine starting. Shot styles pick their sound; from Age 8 story lines open with radio static. Not yet triggered: the siren (wants an "enemy aircraft over your city" alert) and the engine (wants vehicles to exist).
- [x] **S** Music (2026-11-15): from Age 7, *The Japanese Sandman* (Harry Raderman's Novelty Orchestra, 1920) in peacetime and *Alte Kameraden* (Anker-Orchester, CC0) in battle; both public domain in the US and the EU (checked composers' and lyricists' death dates; *It Had to Be You* was dropped because its composer's EU protection runs to the end of 2026). Credited in `assets/CREDITS.md`; `test_music_tracks` loads every track. Later decades could add 1930s–50s recordings as they enter the public domain.

### HUD
- [x] **S** Icons: units and buildings render their own icons from the 3D models (`ui/icon_factory.gd`), so the new vehicles and outfits need nothing; research levels reuse their branch icon. Only a new resource (Oil) would need a drawn icon.
- [x] **S** The age chip and age-up dialog show 12 ages (they read the names from ages.json; checked at Age 9).

## Phase 4: Content, one age at a time

Repeat this checklist for each age, **7 → 12**. Each age ships with its chapter (Phase 5) before the next age starts.

### Per-age checklist
- [ ] Age entry in `data/ages.json`: name, description, cost, time.
- [ ] Monarchy roster: new units and the lines that upgrade (data, figure or vehicle, icons, sounds).
- [ ] Concern roster: the same.
- [ ] New buildings and building upgrades.
- [ ] Research for the age.
- [ ] Crown lands and Dark Pacts: does any regional unit get a modern tier?
- [ ] AI: build order, unit mix and research order for the age.
- [ ] Gallery screenshots, tests, and a short AI-vs-AI soak.

### Age 7, the Federation ✔ done 2026-11-15 (no longer "wip": skirmish can play to Age 7)
Tiers: Grenadier → Sturmtrupp, Musketeer → Rifleman, Field Alchemist → Sanitäter, Kürassier → Armoured Car, Uhlan → Motorcycle Scout (Galicia), Tross Wagon → Supply Lorry; Reaver → Tommy-gun Ghoul, Soul Caller → Gas Trooper, Bonebow → Debt Collector, Bone Cart → Hearse. No new buildings (the tiers train where their lines do); research levels VII exist; the AI fields every tier (checked AI-vs-AI). Chapter 7 shipped with it.

### Age 8, Zeppelins: roster and chapter done 2026-11-15 (still "wip" until the balance pass lands)
Tiers: Kress Gyrocopter → Biplane, Lohner Aethership → Aether Zeppelin, Jäger → Gebirgsjäger; new Radio Spotter (Laboratorium; long sight, Bombardment). Concern: Plague Balloon → Corpse-Zeppelin, Bone Drake → Bat-Plane, Necromancer → Wireless Medium. Chapter 8 shipped with it.

### Age 9, Diesel: roster and chapter done 2026-11-15 (still "wip" until the balance pass lands)
Tiers: Landpanzer → Porsche Heavy Tank, Armoured Car → Light Tank, Supply Lorry → Halftrack (supply and a 6-troop transport); new Arctic Trooper (Kaserne; "hardy": half attrition). Concern: Bone Juggernaut → Undead Panzer, Ghoul Rider → Bone Halftrack, Hearse → Corpse-Truck; Debt Collector → Frost Dead (Age 10, defined early for Chapter 9). Hero: Hedy Lamarr (Frequency Hopping jams and slows enemies; Great Escape). Scenario weather: snow and a polar night (dims the sun). Chapter 9 shipped with it.

### Age 10, Radar: roster done 2026-11-15 (still "wip")
Tiers: Škoda Siege Crawler → Aether Rocket Battery, Kaiserjäger → Paratrooper, Double Eagle → Monoplane Fighter; new Radar Truck (Fabrik; sight 16, `"detector": 9` exposes stealth from 9 tiles) and Rocket Trooper (Schießstand; anti-machine rockets). Concern: Debt Collector → Frost Dead, Abomination → Plated Abomination.

### Roster sketch (to refine age by age)

| Age | Monarchy | The Concern |
|---|---|---|
| 7 Federation (1920s) | Rifleman (Musketeer line), Sturmtrupp with SMG (Grenadier line), Sanitäter (Field Alchemist line), Austro-Daimler armoured car, motorcycle scouts | Debt-bound dead (worker), tommy-gun ghouls, soul-gas troops, hearse car (carries and raises the dead) |
| 8 Zeppelins (early 1930s) | Aether zeppelin (Aethership line), biplane fighter, radio spotter (calls in artillery, reveals), mountain troops (Jäger line) | Corpse-zeppelin, bat-plane, wireless medium (séance caster), séance tower |
| 9 Diesel (late 1930s) | Light tank, Porsche heavy tank (Landpanzer line), halftrack, flak gun, Diesel Walker (Steam Walker line) | Undead panzer (Bone Juggernaut line), biomechanical horror, bone halftrack |
| 10 Radar (1940s) | Radar truck (detects stealth, wide vision), Aether rocket battery, paratroopers, Lamarr jammer | Lich bunker, frost engine (slows), grave rocket battery |
| 11 Atom (late 1940s) | Jet fighter, reactor walker, flame trooper, the **Aether bomb** (superweapon) | Soul reactor, armoured abomination, wraith jet |
| 12 Rockets (1950s) | Rocket artillery, the Viribus mech (Aether Colossus line) | Necropolis titan (Bone Colossus line), soul rocket |

### New buildings (sketch)
- Monarchy: **Motor Works** (vehicles; the Fabrik grows into it), **Airfield** (planes; replaces the Adlerhorst for fixed wings), **Radio Station / Radar Station**, **Flak Tower** (the Festungsturm line), **Aether Reactor**, **Rocket Gantry**, **Gemeindebau** apartment blocks (population).
- The Concern: **Concern Headquarters** (city), **Foundry**, **Séance Tower**, **Crematorium Reactor**, **Cold Storage** (population of the waiting dead), **Bone Silo**.
- Wonders 7–12 (ideas): the Großglockner High Alpine Road, the Kaprun dam (1955), a Danube radio tower, the Federal Parliament of the crown lands.

### Decisions to make on the way
- [ ] **Oil as a new resource** from Age 8 or 9 (Galicia was a real oil region, and its city already has derricks), or keep Coal for engines?
- [ ] **Superweapons:** the Aether bomb, and the Concern's answer. Rise of Nations used an Armageddon clock that ends the game for everyone if too many are used. Copy that, cap them at one per game, or keep them campaign-only?
- [ ] **Refits:** automatic on age-up, or paid per line?
- [ ] **Air power:** planes as normal units, or a separate airfield sortie system (they take off, strike and return)?

## Phase 5: Campaign 2

- [x] **M** Menu (2026-11-15): two campaigns on the Campaign page (Campaign 2 unlocks when Chapter 6 is won); `Scenario.CAMPAIGNS` describes each (chapters, intro, epilogue, progress key, what unlocks it); chapters are numbered across both (VII–XII); finishing Campaign 1 offers to begin Campaign 2.
- [x] **S** Intro title cards for Campaign 2 (`INTRO2`, 1918–1926) and its epilogue (`EPILOGUE2`).
- [ ] **M** Heroes: old Franz Ferdinand (staff car), Hedy Lamarr, Lise Meitner, Schrödinger, Porsche, Tesla (aged), Houdini's ghost. Abilities in `data/abilities.json`.
- [ ] **M** Bosses: Szentkirályi in each of his forms (1926 shade, 1934 foundry-lord, 1955 necropolis lich), the Concern's machines.
- [ ] **M** Scenario toolkit additions: ~~weather~~ (done: `scenario.weather` = {"snow", "night"}), a player choice with a remembered outcome (the bomb in Chapter 11), ~~market events~~ (Chapter 8 does them in script), fronts with many capture points (Chapter 10).
- [ ] Chapters, each built with its age in Phase 4:
  - [x] **L** 7 Rosabelle, Believe (Age 7): three séance parlours give the words of Houdini's code and free his ghost; then storm the counting-house (guarded, with waves) where Szentkirályi steps out, speaks and leaves; Vienna sends reinforcements with Landpanzers, since rifles can't crack buildings. Bot-played: won with 7 units left.
  - [x] **L** 8 Black Thursday (Age 8): Vienna and four crown-land cities; every 70s the Concern "buys" a city's debt and its collectors loiter inside the borders out of the guns' reach, draining loyalty (~24s to a revolt if nobody answers); Federal Charters hold a city at half; corpse-zeppelins raid the supply lorries; reinforcements every third buy-out. Hold 12 minutes; three lands lost loses. Bot (charters two cities, answers every buy-out): won with nothing lost.
  - [x] **L** 9 The Ice Crown (Age 9): snow; build a Kaserne before the light goes (3 min), hold Camp Tegetthoff through the polar night (5 min of Frost Dead waves; a supply zeppelin midway), sunrise freezes the attackers near the camp, then destroy the foundry under the glacier (it collapses at 1 HP) guarded by the Ice Engine. Hedy Lamarr must survive. The Concern runs no AI here: an outpost, scripted. Bot: won with 3 units left.
  - [ ] **L** 10 The Long Winter (Age 10)
  - [ ] **L** 11 The Aether Bomb (Age 11)
  - [ ] **L** 12 The Treaty of the Living (Age 12)
- [ ] **S** Extend `tests/campaign_bot.gd` and the chapter tests to every new chapter.

## Phase 6: Balance, performance and polish

- [ ] **L** Balance the full ladder: `tests/run_balance.sh` across Classic, Modern and Full games; both sides about 50/50; game lengths per preset.
- [ ] **M** Performance with vehicles, aircraft and civilian traffic: profile battles of 150 and 400 units on the Iris Xe laptop at Medium; LODs for vehicles; cap ambient traffic per quality setting.
- [ ] **M** AI: modern-age tactics (combined arms, air cover, anti-air, keeping tanks with infantry).
- [ ] **S** Docs: README features and screenshot, technical.md, story.md "as built".
- [ ] **M** Full playtest of both campaigns, then fix.
