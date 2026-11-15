# Rise of Magic: story bible

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

## Open questions
1. **Hungary in skirmish games.** In the story it's Rudolf's ally; in skirmish it's currently a third side hostile to everyone. Keep that, or ally it with the Covenant?
