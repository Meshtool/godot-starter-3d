# Mesh City: Gonzo Run

A fever-dream drive down the repo strip. Every public Meshtool and RightOnPar repo is a neon tower.

- **Tower height**: repo size.
- **Glow**: how recently the repo was pushed. Hot means fresh.
- **Orbs**: one per open issue/PR, plus one per repo. Grab them all to sync the estate.
- **Fever**: climbs with every orb. The screen warps, the colors split, and the ink spreads.
- **Cards**: walk up to a tower to read its card, then press **E** to open it on GitHub.

Controls: WASD / arrows to move, SPACE to jump, E to open the repo.

## How it stays live
CI runs `tools/fetch_repos.py` before every export, and also daily on a schedule, so the skyline tracks the repos. Only public repos are included. If GitHub is unreachable, the build uses the committed `data/repos.json` snapshot.

On `main`, the web build ships to itch.io via butler. That step needs the `BUTLER_CREDENTIALS` repo secret and the itch page `meshtool/godot-starter-3d`, and it skips cleanly if the secret is missing.

## Dev
`godot --path . -- --demo` runs attract mode: an autopilot drives to every orb, which serves as a smoke test of the full run.

Art and writing are original, made in an ink-splatter, gonzo-journalism spirit.
