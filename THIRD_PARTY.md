# Borrowed presentation assets

Only these assets are vendored. Gameplay, recording, replay, Solo's text, and the
proof UI are maintained in this project.

| Component | Source | License | Local file |
| --- | --- | --- | --- |
| Inter Variable 4.1 | https://github.com/rsms/inter/releases/tag/v4.1 | SIL Open Font License 1.1 | `assets/fonts/InterVariable.ttf` |
| Spark particle texture | https://github.com/godotengine/godot-demo-projects/blob/b761b4cd5718a7118f2c95eb55f181d0a5f004f1/3d/physics_interpolation/spark_particle.png | MIT, Godot Engine contributors | `assets/particles/spark.png` |

The existing Solo character from merged PR #8 is original project artwork, not a borrowed asset.

The corresponding license texts are next to each asset and included in the web
package. Assets are unmodified. No Kenney files were imported.

Rendering decisions follow Godot 4.3's official performance guidance:
https://docs.godotengine.org/en/4.3/tutorials/performance/optimizing_3d_performance.html

The Proof Course field uses small two-triangle particle billboards, bounded particle counts,
2x MSAA, a low-effects toggle, opaque UI panels, and a compatibility-renderer
halo. It does not depend on Forward+ bloom for its web appearance. These are
implementation choices, not a measured frame-rate guarantee on user hardware.
