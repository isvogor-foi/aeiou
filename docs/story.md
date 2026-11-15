# A.E.I.O.U.: story bible

Decided with the user on 2026-11-09. Inspired by Dragony's concept album *Viribus Unitis* (2021) and the single *The Dead Queen's Race* (2023): an alternate end of the Habsburg monarchy with steampunk, magic and the undead. **We keep the spirit and the shared historical figures but write our own plot, motives and names.**

See also `docs/aetheric_monarchy.md` (faction, ages, crown lands).

## Tone
A **dark epic played with pulp energy and a knowing wink** (think *Hellboy*, *Indiana Jones*):
- The stakes are real and the world is grim: smog, dusk, a dying empire.
- The heroes are larger than life: Tesla, Houdini, an old Emperor in steam armour.
- The dialogue may be funny. Viennese gallows humour and dry one-liners, never parody.

**Running joke:** the reformed Habsburgs no longer bully Switzerland, and for once in their history they **win their wars**. The old saying was *"Bella gerant alii, tu felix Austria nube"*: let others wage war; you, happy Austria, marry. The Swiss beat the Habsburgs at Morgarten (1315) and Sempach (1386).

## The world before 1914 (the baseline everyone knows)
- Rudolf II's alchemists in Prague's Golden Lane unlocked **Aether**.
- By the 1800s the Habsburg empire runs on steam and Aether: airships, Aether muskets, Tesla coils.
- History otherwise went as we know it: 1848, 1866, the Compromise of 1867 with Hungary, Mayerling in 1889, Sisi's murder in Geneva in 1898.

## The divergence: Sarajevo, 28 June 1914
- **The shot misses.** Archduke Franz Ferdinand survives.
- He pushes through the reform he always wanted: a **federal empire of equal crown lands**. This is Aurel Popovici's *United States of Greater Austria* (1906).
- The Habsburgs come out of it **reformed and noble**: an empire of equals, *Viribus Unitis* ("with united forces").

## The secret: Rudolf and Hungary
- **Mayerling, 1889, was staged.** That night Crown Prince Rudolf crossed into undeath. The world buried an empty coffin in the Kapuzinergruft.
- For 25 years he has hidden in **Hungary**, sheltered by magnates who share his hatred of Vienna's direction. Rudolf and his mother Sisi both loved Hungary.
- **Why Hungary joins him:** federation ends Hungary's rule over the Croats, Slovaks and Romanians. So **Hungary as a whole stands with Rudolf**: the living and the dead together against the Habsburgs. Historically, Hungarian leaders fought Franz Ferdinand's plans bitterly.
- The **Umbral Covenant** is Rudolf's army of the dead and his necromancers. The Sarajevo assassins carried its sigils: the shot was never only Serbian.

## The cast
- **Franz Ferdinand.** The protagonist: the survivor of Sarajevo and the reformer.
- **Franz Joseph.** 84 in 1914. He abdicates to Franz Ferdinand early in the campaign. Dying in 1916, he is kept alive by **Tesla's steam armour** and returns as the **Iron Emperor** for a last battle. This is our own take on the armoured old Kaiser.
- **Rudolf, the Umbral Sovereign.** The hidden heir and the main villain. His motive is to undo his mother's death and claim the throne.
- **Empress Elisabeth (Sisi).** Murdered in 1898. In 1917 Rudolf **raises her as the Pale Empress** at **Gödöllő**, the Hungarian palace she loved, and her return binds Hungary to him. She is **Elisabeth, the Pale Empress** (replacing the unit "The Dead Queen").
- **Nikola Tesla.** Born in the Habsburg Military Frontier. He comes home from America to build the Aether war machines and the Iron Emperor's armour.
- **Harry Houdini.** Born in Budapest. As the great debunker of fake mediums, he is the one man who can tell real necromancy from tricks, and **he unmasks the conspiracy**.

## The campaign: six chapters, 1914–1918, one per age

| # | Age | Chapter | Story | Built from |
|---|---|---|---|---|
| 1 | Margraves | **The Shot That Missed** (June 1914) | Escort the Archduke through Sarajevo. In the wreckage, the assassins carry strange sigils. | Mission 1 |
| 2 | AEIOU | **The Empty Tomb** (autumn 1914) | Houdini declares the sigils genuine. A raid on Mayerling and the Kapuzinergruft finds Rudolf's coffin empty: the reveal. | New |
| 3 | Golden Lane | **The Federation** (1915) | Franz Ferdinand proclaims the crown lands. Hungary breaks away and openly joins Rudolf. Franz Joseph abdicates. Tesla comes home. | Crown-land play from mission 3 |
| 4 | Reform | **The Siege of Vienna** (1916) | The Covenant and the Hungarian army at the gates. The dying Franz Joseph returns in Tesla's armour as the Iron Emperor to hold the Hofburg. | Mission 2 |
| 5 | Congress | **The Empress Rises** (1917) | Rudolf raises Sisi at Gödöllő. Stop the ritual, then face the Undead Empress. | New |
| 6 | Aether Monarchy | **Viribus Unitis** (1918) | Bring the five AEIOU relics home and storm Rudolf's seat at Buda. | Mission 3, reworked |

**Ending: triumph with a cost.** The Federation is proclaimed and Rudolf is defeated. Franz Joseph falls in his last stand and the empire pays dearly, but it stands, united, and for once it won.

## Telling it to the player
The player must learn the premise **before the first mission**: the campaign opens with an introduction (a narrated briefing or title cards) before Chapter 1. Draft text:

> *Vienna, 1914.* For three centuries the Habsburgs have ruled by the light of Aether, the alchemists' fire first kindled in Rudolf II's Prague. Airships cross the Danube; Tesla coils hum in the Hofburg; and the old Emperor Franz Joseph, eighty-four years old, still signs every paper himself.
>
> But the empire is tired. Its peoples want a voice, its wars are lost more often than won, and in Budapest the magnates whisper that Vienna's day is done.
>
> On the 28th of June, in Sarajevo, a young man steps from the crowd and fires at the heir, Archduke Franz Ferdinand.
>
> **He misses.**
>
> The Archduke lives to keep his promise: an empire of equals, every crown land free under one crown. *Viribus Unitis.*
>
> Some do not want it. And some of them, it turns out, were never meant to be alive at all.

Each chapter then opens with a short briefing card (date, place, a two- or three-line situation) in the same voice.

## Settled (2026-11-14)
- **The Undead Empress** is *Elisabeth, the Pale Empress*.
- **The conspirators' face** is a fictional magnate, **Count Árpád Szentkirályi**, so no real politician is tied to undead pacts.
- **Heroes from the wrong century** become namesakes: *Colonel Radetzky the Younger* (the Field Marshal's great-grandson) and *Ban Jelačić the Younger* (grand-nephew of the Ban of 1848). Prince Eugene's siege lines go to Field Marshal Boroević.
- **The introduction** is three title cards on the mission screen before Chapter 1 (skippable), then a dated briefing card per chapter. The text lives in `scenarios/scenario.gd` (`INTRO`, `MISSIONS`, `EPILOGUE`).

## The chapters as built
| # | Script | Play |
|---|---|---|
| 1 | `m1_sarajevo.gd` | Escort the Archduke past four ambushes. |
| 2 | `m2_tomb.gd` | Stealth: Houdini past watcher cones into the crypt (being seen sends a squad). Then the column destroys the half-built Grave Engine at Mayerling. |
| 3 | `m3_federation.gd` | Base-building: proclaim 3 crown lands. At 2 lands (or 9 minutes) Hungary secedes, Franz Joseph abdicates, Tesla arrives. Take Szentkirályi's stronghold. |
| 4 | `m4_vienna.gd` | Hold 10 minutes; Hungarian flank attacks from wave 2; the Iron Emperor marches out at 4:30. |
| 5 | `m5_empress.gd` | Capture 3 ritual circles within 8 minutes; the Pale Empress rises at 45/60/80/100% health for 0/1/2/3 circles left burning. Rudolf leaves for Buda. |
| 6 | `m6_viribus.gd` | Hold the five relics, then storm Buda: Rudolf boss, the Iron Emperor and all crown lands join. Franz Joseph dies when Rudolf falls. |

## Campaign 2: The Undying Century (1926–1955)

Decided with the user on 2026-11-15. Six more chapters, one per new age (7–12). Nothing is built yet.

### Decisions
- **Villain: Count Árpád Szentkirályi.** He fled east in a hearse at the end of Chapter 3 and comes back undead: a lich-magnate who rebuilds the Covenant as a business, the **Szentkirályi Concern**. It buys debts, bankrupt cities and the dead, then turns them into an industrial army.
- **Protagonist: Franz Ferdinand, all the way to 1955.** He's kept going by Aether medicine (and stubbornness), from 63 to 92. Running wink: like Franz Joseph before him, he still signs every paper himself.
- **No real-world fascism or WWII.** The surviving federation prevented the war we know. The great war of this century is against the dead. No real dictators are shown; at most a dry aside.
- **Six new ages, 7–12,** with new rosters for both sides; skirmish can play the whole ladder.

### Ages 7–12 (working names)
| Age | Name | Years | Monarchy flavour | Covenant flavour |
|---|---|---|---|---|
| 7 | Age of the Federation | 1920s | Jazz-age Vienna; submachine guns, armoured cars | The Concern's debt-bound dead, gas troops |
| 8 | Age of Zeppelins | early 1930s | Aether zeppelins, radio, biplanes | Corpse-zeppelins, wireless séances |
| 9 | Age of Diesel | late 1930s | Porsche heavy tanks, dieselpunk walkers | Undead panzers, biomechanical horrors |
| 10 | Age of Radar | 1940s | Radar, frequency hopping (Hedy Lamarr), rocket artillery | Liches in bunkers, frost engines |
| 11 | Age of the Atom | late 1940s | Jets, Aether reactors (Lise Meitner) | Soul reactors, abominations in plate |
| 12 | Age of Rockets | 1950s | Rockets, the Aether bomb's long shadow | The Concern's final machine-necropolis |

### Between the campaigns (1918–1926)
- Rudolf is ended at Buda, but Szentkirályi was never there. He rode east in a hearse in 1915 (Chapter 3) and spent the war somewhere colder, learning what Rudolf knew.
- The Federation's peace years: crown lands with their own parliaments, the Danube a highway of Aether barges, Vienna a city of jazz, coffeehouses, cinema and radio. The empire is not loved by everyone, but it is, for once, solvent.
- The dead do not rest. Rudolf's necromancers are scattered and unemployed. Szentkirályi hires them.

### The villain: Count Árpád Szentkirályi
- In 1915 a living Hungarian magnate and ringleader of the secession. By 1926 he is a **lich-magnate**, and he has learned that the dead make excellent employees: they never strike, never sleep and never ask for wages.
- His power is the **Szentkirályi Concern**, a necro-industrial company. It buys debts, bankrupt cities and the bodies of the poor, and it pays dividends in undeath. Its sigil is a ledger with a skull.
- His arc rises one chapter at a time: a whisper (1926), a market (1929), a foundry in the ice (1934), an army (1941), a reactor (1945), a necropolis (1955).
- He is everything Franz Ferdinand is not: an empire of owners instead of an empire of equals.

### Franz Ferdinand, 1926–1955
- 63 when the campaign opens, 92 at its end. Kept going by Aether medicine from the Golden Lane, a temper, and the conviction that nobody else will read the paperwork.
- Running wink: like Franz Joseph before him, he still signs every paper himself. By 1955 the papers are typed, mimeographed and sent by radio, and he still signs them.
- He never fights in steam armour; that was his uncle's way. He leads from a staff car, then an armoured train, then a jet.

### Chapters
| # | Age | Chapter | Place and date | Play | New on the field |
|---|---|---|---|---|---|
| 7 | Federation | **Rosabelle, Believe** | Vienna and Budapest, Oct–Nov 1926 | Houdini dies on Halloween. At a séance his widow's code ("Rosabelle, believe") comes through: the Concern holds his soul in a medium's cabinet. Stealth and raid: shut down the séance parlours across the city, then storm the Concern's first counting-house. The first sight of Szentkirályi, who walks away. | SMG assault troops, riflemen, armoured cars; the Concern's tommy-gun ghouls and gas troops |
| 8 | Zeppelins | **Black Thursday** | The crown lands, Oct 1929 | The crash. The Concern buys bankrupt cities, and their loyalty collapses. Hold the federation together: charters, garrisons and an economy under siege, while corpse-zeppelins raid the supply lines. Defeat: three crown lands sold to the dead. | Aether zeppelins, biplanes, radio spotters; corpse-zeppelins, séance towers |
| 9 | Diesel | **The Ice Crown** | Franz Josef Land, 1934 | An airship expedition to the Arctic archipelago Austria-Hungary discovered in 1873. Land, build a camp on the ice, hold through the polar night, and destroy the Concern's foundry under the glacier. Pulp adventure: Indiana Jones in a snowstorm, with Hedy Lamarr on the radio. | Porsche heavy tanks, halftracks, mountain troops; undead panzers, frost-bound horrors |
| 10 | Radar | **The Long Winter** | The Carpathians, winter 1941 | Szentkirályi's dead march on the federation. A great front battle: hold the passes, then break through. Tesla, 85, gives the empire his last invention (radar against the séance-fog); he dies before the war ends, in January 1943, as he did in our history. | Radar, Aether rocket batteries, paratroopers; liches in bunkers, frost engines |
| 11 | Atom | **The Aether Bomb** | Vienna and the Pannonian plain, 1945 | Lise Meitner splits Aether. The Concern has built a soul reactor that will raise every grave from Pressburg to Belgrade. Raid it. At the end, a choice: drop the Aether bomb (win at once, at a real and lasting cost to the land) or fight in on foot (harder, nothing lost). The choice is remembered in Chapter 12. | Jets, Aether reactors, the bomb; soul reactors, armoured abominations |
| 12 | Rockets | **The Treaty of the Living** | The Concern's necropolis and Vienna, 1955 | The finale. Storm the machine-necropolis and destroy Szentkirályi. Then end the war the Austrian way, with a treaty, signed in the Belvedere in the real State Treaty year, and perhaps a wedding (*tu felix Austria nube*). Franz Ferdinand, 92, signs it himself. | Rockets, the Viribus mech; the necropolis titan |

### Ending
Triumph again, smaller in its cost but heavier in its meaning: the Federation outlives the century that should have destroyed it. If the Aether bomb was used, a scar on the Pannonian plain glows at night for a hundred years. Franz Ferdinand signs the treaty, puts down the pen, and for the first time in forty years takes a holiday.

### Cast additions
| Who | Role |
|---|---|
| **Hedy Lamarr** (b. Vienna 1914) | Film star and inventor. Radio, frequency hopping: jams the Concern's séance-wireless. Hero from Chapter 9. |
| **Lise Meitner** (b. Vienna 1878) | Physicist. Splits Aether in Chapter 11 and carries the moral weight of the bomb. |
| **Erwin Schrödinger** (b. Vienna 1887) | Proves the dead are both. Comic relief with a box. |
| **Sigmund Freud** (Vienna) | Reads the dreams of the dead; briefings and hints. |
| **Ferdinand Porsche** (b. Bohemia 1875) | Builds the tanks of the Diesel age. |
| **Nikola Tesla** | Until his death in January 1943 (Chapter 10). |
| **Harry Houdini** | Dies in 1926; his freed soul may return once, as a ghost hero, in Chapter 12. |

### The chapters as built (2026-11-15)
| # | Script | Play |
|---|---|---|
| 7 | `m7_rosabelle.gd` | Close three séance parlours (words of Houdini's code; his ghost joins), then storm the Concern's counting-house; Szentkirályi appears and walks away. Reinforcements bring Landpanzers. |
| 8 | `m8_black_thursday.gd` | Four crown-land cities; buy-outs every 70s send collectors to loiter in a city's borders and drain its loyalty; charters, garrisons and quick answers hold the Federation for 12 minutes. Three lands lost loses. |
| 9 | `m9_ice_crown.gd` | Snow. Build a Kaserne before the light goes; hold Camp Tegetthoff through the polar night (Frost Dead waves, a supply zeppelin); sunrise freezes the attackers; destroy the foundry and the Ice Engine. Hedy Lamarr must survive. |
| 10 | `m10_long_winter.gd` | Hold three Carpathian passes (contested points) against the winter offensive; Tesla's radar comes online at 4:00; break through to the winter headquarters. Tesla must survive. |
| 11 | `m11_aether_bomb.gd` | Take two relay pylons, then choose: drop the Aether bomb (wins at once, scars the plain) or go in on foot against the Reactor Lich. Remembered. Lise Meitner must survive. |
| 12 | `m12_treaty.gd` | Break the necropolis gates, then end Szentkirályi as the crown lands send their regiments. The bomb's scar and a weakened Count, or Houdini's ghost. The Treaty; a wedding if no bomb fell. |

## Open questions
1. **Hungary in skirmish games.** In the story it's Rudolf's ally; in skirmish it's currently a third side hostile to everyone. Keep that, or ally it with the Covenant?
