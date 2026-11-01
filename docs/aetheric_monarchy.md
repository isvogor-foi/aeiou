# The Aetheric Monarchy: design notes

The setting is an alternate Habsburg empire.
- Rudolf II's Prague alchemists unlocked **Aether**.
- By the 1800s Aether drives a steam-and-spell empire of many peoples.
- In 1914 the shot in Sarajevo misses, and Franz Ferdinand federalises the crown lands (Popovici's *United States of Greater Austria*, 1906) instead of losing them.

It replaces the Aurelian Collegium. The **Umbral Covenant** stays as a fictional necromantic enemy.

## Decided (Phase 5.5)
- **Resources:** Thaler (gold), Timber, Provisions (herbs) and Aether (mana). The data keys stay `gold` / `timber` / `herbs` / `mana`. Coal arrives with Age 4 steam.
- **Ages:** the Margraves, AEIOU, the Golden Lane, Reform, the Congress, the Aether Monarchy.
- **Crown lands** (`data/crown_lands.json`):
  - The capital is Austria. Every other city can be proclaimed one land, and each land only once.
  - **Croatia:** Grenzer.
  - **Bohemia:** War Wagon.
  - **Tyrol:** Standschütze.
  - Each land also grants a modest bonus.
- **Viribus Unitis:** +5% damage per extra crown land among friendly fighters within 6 tiles, up to +15%.
- **Art:** recoloured KayKit textures (`devtools/recolor.py`), plus procedural muskets, hats, wagons, the double eagle and gliders.

## Planned
- **Phase 6 (Ages 4–6):**
  - Steam and Coal (Styrian Erzberg, Bohemian mines).
  - The Škoda Mortar, the Lohner Aethership and the Tegetthoff Ironclad's ram.
  - Hungary (Hussar) and Galicia (Uhlan) crown lands, once there are horse models.
  - Wonders: the Prague Orloj, St. Stephen's and the Pummerin, the Semmering Railway, the Hofburg Treasury.
  - Hero choices: Maria Theresa, Prince Eugene, Archduke Charles, Andreas Hofer, Tegetthoff, Franz Ferdinand.
  - The **AEIOU victory**: hold five treasury relics (the Imperial Crown, the Holy Lance, the Agate Bowl, the "Unicorn Horn", the Imperial Orb).
- **Phase 6.5 (loyalty):**
  - Per-city loyalty, lowered by over-expansion and war-weariness.
  - Rebellion turns a city neutral.
  - **Federal Charters** (Age of the Congress) trade taxes for loyalty.
- **Later regional units:**
  - Croatia: the Pandur (forest camouflage, plunder) and the Bosniak (fearless).
  - Bohemia: the Píšťala Gunner, the Golem of Prague and the Rudolfine Alchemist.
  - The Alps: the Kaiserjäger with the Girandoni air rifle, the Bergführer (mountain movement, avalanche) and Hofer's Levy.
  - Air: the Uchatius Balloon (drifts with the wind).
  - Vienna: the Kapellmeister (band aura).
