# Asset credits

All third-party art is CC0 (public domain). See each pack's LICENSE.txt.

| Folder | Pack | Author | Source |
|---|---|---|---|
| `kaykit/medieval` | KayKit Medieval Hexagon Pack 1.0 (subset) | Kay Lousberg | github.com/KayKit-Game-Assets/KayKit-Medieval-Hexagon-Pack-1.0 |
| `kaykit/adventures` | KayKit Character Pack: Adventurers 1.0 | Kay Lousberg | github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0 |
| `kaykit/skeletons` | KayKit Character Pack: Skeletons 1.0 | Kay Lousberg | github.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0 |

Which model each unit, building and resource uses is set in `data/visuals.json`.

## Music (public domain / CC0, from Wikimedia Commons)

| File | Work | Performer | License |
|---|---|---|---|
| `music/kaiserhymne.ogg` | Haydn, *Gott erhalte Franz den Kaiser* (Kaiserhymne) | Commons: "Gott erhalte Franz den Kaiser.ogg" | CC0 |
| `music/radetzky_march.mp3` | Johann Strauss I, *Radetzky March* | "The President's Own" U.S. Marine Band | Public domain (U.S. government work) |
| `music/blue_danube.mp3` | Johann Strauss II, *An der schönen blauen Donau* | U.S. Marine Band | Public domain (U.S. government work) |
| `music/japanese_sandman.mp3` | Richard Whiting, *The Japanese Sandman* (1920) | Harry Raderman's Novelty Orchestra, 1920 | Public domain (composer d. 1938, lyricist d. 1952; 1920 recording). Commons: "\"The Japanese Sandman\" (1920) 1920s dance band music for flappers Harry Raderman's Novelty Orchestra.opus", converted to MP3 |
| `music/alte_kameraden.mp3` | Carl Teike, *Alte Kameraden* (1889) | Anker-Orchester | CC0 / public domain (composer d. 1922). Commons: "CC0-CH - Anker-Orchester - Alte Kameraden - Carl Teike - Anker-5387-10815.flac", converted to MP3 |

The last two play from the Age of the Federation (7) on, in peace and in battle.

Sound effects are synthesised in code (`audio/sfx.gd`).

## Trees (CC0, Quaternius)

`quaternius/nature/*.fbx`: from Quaternius's **Ultimate Stylized Nature** pack (CC0, quaternius.com),
fetched from the Godot-adjusted repository `walterpalladino/godot-quaternius-ultimate-stylized-nature`
(MIT for its Godot adjustments). Only the meshes are used; materials are set in code.

## Derived models

`kaykit/*/*_hd.glb` are smooth-subdivided copies of the KayKit characters (CC0), made by
`devtools/subdivide.py`. Roof atlases in `recolor/roofs_*.png` come from `devtools/roofs.py`.

## Realistic figures (CC0, Quaternius)

`quaternius/ual/AnimationLibrary_Godot_Standard.gltf` (+ .bin): Quaternius's **Universal Animation
Library** (standard, free version, CC0), from `J-Ponzo/gltf-universal-animation-library`.
Uniforms, hats and weapons are built in code on top of it (`view3d/figure.gd`).
