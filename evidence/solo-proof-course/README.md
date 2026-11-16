# Solo Proof Course review evidence

This phase preserves the Solo character and roadside city already on main, adds
a recorded Proof Course inside the same game, and makes the Mesh Tag sample
verifier require an independently trusted issuer key.

73 automated assertions/tests passed, plus six rendered city smoke checks.
The course and city round trip ran with Godot 4.3 compatibility rendering on Mesa
software graphics. The screenshots show full effects after the test toggles them;
reduced effects is the default. These are native engine screenshots, not browser
or performance benchmarks. The demo completes 15 repo checkpoints in 1,232 fixed
ticks (20.533 seconds of simulation). It is explicitly labeled demo and is not
a signed Runtime receipt or evidence of human play.

Web export passed. Browser execution was not verified because the browser runtime
requires a Unix socket unavailable in this environment. No itch.io upload or
production merge was performed for this phase. CI is a separate verification.

The build fingerprint binds both scenes, movement rules and public repo snapshot.
Verify the demo JSON from this checkout with:

```sh
godot --headless --script tools/verify_run.gd -- evidence/solo-proof-course/demo-run.json
```

The earlier phase2-2026-11-14 evidence is superseded by this combined-game review.
