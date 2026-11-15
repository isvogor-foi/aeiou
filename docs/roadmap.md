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

## Phase 3: Shared art systems

Each of these is a toolkit that every age then uses. Build and gallery-test each before making content.

### People: uniforms by era (`view3d/figure.gd`, `view3d/gear.gd`)
- [ ] **M** Era layer on outfits: one unit type can be dressed for its era without a new figure.
- [ ] **M** Monarchy kit, 1920s → 1950s: peaked caps and Bergmütze, short tunics, puttees → boots, webbing, steel helmets of a later pattern, flight suits, tank crew overalls, radiation hoods (Age 11–12). Team colour stays on collar, armband and helmet stripe.
- [ ] **M** Concern kit: undead in suits and bowler hats (the debt-bound), gangster ghouls with tommy guns, gas troops in rubber, frost-crusted soldiers, armoured abominations in riveted plate.
- [ ] **M** Weapons: bolt-action rifle, submachine gun, light machine gun, bazooka/rocket tube, flamethrower (updated), radio pack, binoculars.
- [ ] **S** Animations: check the Quaternius library covers SMG fire, prone/crouch, throwing (grenades) and carrying a radio; add procedural poses where it doesn't.
- [ ] **S** `tests/unit_gallery.gd` renders every era.

### Vehicles (`view3d/vehicles.gd`, routed through `view3d/machines.gd`)
- [x] **L** Vehicle kit (2026-11-15): wheels that turn with the distance driven (`"roll"`), track belts whose tread scrolls (`"tread"`, a small instance-uniform shader), turrets that swing to the last target and back (`"turret"`), hull rumble while driving (`"rumble"` in visuals.json), exhaust smoke, headlights, seated crew. Moving parts are baked one mesh each; the rest of the vehicle is one mesh per material, as before. `tests/vehicle_gallery.gd` parks and drives them all; `test_vehicle_kit` checks every model.
- [x] **M** Cars and trucks: Austro-Daimler staff car and armoured car, lorry, motorcycle with sidecar, halftrack.
- [x] **M** Tanks: light tank, Porsche heavy tank, Aether rocket truck (walker refits come with their ages).
- [x] **M** Aircraft: biplane, Aether zeppelin, monoplane fighter, jet. Propellers spin (with a blur disc), jets leave contrails that stay behind in the world; planes bank into turns and, with `"circle"` in visuals.json, orbit slowly while idle. (The Lohner Aethership keeps its own model.)
- [x] **M** Concern machines: hearse, corpse-truck, undead panzer, bone halftrack, corpse-zeppelin, bat-plane (flapping membrane wings), wraith jet (soul-green trail).
- [ ] **S** Movement feel: vehicles turn wide, accelerate and brake; tracks rotate in place. Check the formation and separation code copes with long, fast units.
- [ ] **S** Existing machines (Landpanzer, Bone Juggernaut, crawlers) could move to the kit so their wheels and turrets come alive too.

### Buildings that keep evolving (`view3d/buildings.gd`)
- [ ] **L** `_age_dress` for 7–12, cumulative like Ages 1–6:
  - 7 Federation: electric street lamps, neon signs, cinema marquees, tram wires.
  - 8 Zeppelins: mooring masts, radio aerials, Art Deco façades.
  - 9 Diesel: concrete, steel-frame extensions, fuel tanks, garage doors.
  - 10 Radar: radar dishes, searchlights, sandbags, flak on roofs (Vienna's real flak towers).
  - 11 Atom: reactor domes, cooling towers, warning stripes.
  - 12 Rockets: gantries, glass and steel, antenna masts.
  - The Concern: a corporate necropolis: office towers of black glass and bone, ledger sigils, crematorium stacks, cold-storage vaults.
- [ ] **M** City designs per crown land, modern versions (Austria's palace with a radio mast; Galicia's oil city grows refineries; Bohemia's Prague spires with Škoda works).
- [ ] **S** `tests/building_gallery.gd` renders ages 1–12.

### City life and ambience (`view3d/ambience.gd`)
- [ ] **M** Civilian traffic inside your borders from Age 7: cars, trams, buses and pedestrians on the cobbled city ground. Purely visual and culled off screen.
- [ ] **S** Night lighting grows with the ages: gas → electric → neon → floodlight.
- [ ] **S** Smog and contrails thicken with industry.

### Effects and sound
- [ ] **M** Effects: SMG tracer bursts, grenade and shell explosions, rocket trails, flak bursts, the Aether bomb flash and its lasting scar on the ground.
- [ ] **M** Sound (`audio/sfx.gd`): SMG and machine-gun fire, engines (car, tank, prop, jet), sirens, radio static, rocket launch.
- [ ] **S** Music: find public-domain recordings for the 1920s–50s (early jazz and dance band recordings, and military marches). Check each licence in `assets/CREDITS.md`.

### HUD
- [ ] **S** Icons for the new units, buildings and research (`ui/hud_icons.gd`), and for Oil if it's added.
- [ ] **S** The age chip and age-up dialog show 12 ages.

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

- [ ] **M** Menu: two campaigns on the Campaign page (Campaign 2 unlocks when Campaign 1 is won); `Scenario.CAMPAIGN` becomes a list per campaign; progress per campaign in `user://campaign.cfg`.
- [ ] **S** Intro title cards for Campaign 2 (1918–1926, see story.md), and an epilogue.
- [ ] **M** Heroes: old Franz Ferdinand (staff car), Hedy Lamarr, Lise Meitner, Schrödinger, Porsche, Tesla (aged), Houdini's ghost. Abilities in `data/abilities.json`.
- [ ] **M** Bosses: Szentkirályi in each of his forms (1926 shade, 1934 foundry-lord, 1955 necropolis lich), the Concern's machines.
- [ ] **M** Scenario toolkit additions: weather (the polar night and blizzards for Chapter 9), a player choice with a remembered outcome (the bomb in Chapter 11), market and economy events (Chapter 8), fronts with many capture points (Chapter 10).
- [ ] Chapters, each built with its age in Phase 4:
  - [ ] **L** 7 Rosabelle, Believe (Age 7)
  - [ ] **L** 8 Black Thursday (Age 8)
  - [ ] **L** 9 The Ice Crown (Age 9)
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
