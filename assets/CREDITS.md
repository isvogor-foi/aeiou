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

Sound effects are synthesised in code (`audio/sfx.gd`).

## Trees (CC0, Quaternius)

`quaternius/nature/*.fbx`: from Quaternius's **Ultimate Stylized Nature** pack (CC0, quaternius.com),
fetched from the Godot-adjusted repository `walterpalladino/godot-quaternius-ultimate-stylized-nature`
(MIT for its Godot adjustments). Only the meshes are used; materials are set in code.

## Derived models

`kaykit/*/*_hd.glb` are smooth-subdivided copies of the KayKit characters (CC0), made by
`devtools/subdivide.py`. Roof atlases in `recolor/roofs_*.png` come from `devtools/roofs.py`.
