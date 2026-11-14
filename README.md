# Mesh City: Proof Run

**Every run, proven.** A drive down the repo strip where every public Meshtool and RightOnPar repo is a neon tower, and every run is headed for a signed receipt anyone can check, whether a human or an AI agent played it (Proof of Play).

- **Tower height**: repo size.
- **Glow**: how recently the repo was pushed. Hot means fresh.
- **Orbs**: one per open issue/PR, plus one per repo. Grab them all to sync the estate.
- **Fever**: climbs with every orb. The screen warps, the colors split, and the ink spreads.
- **Cards**: walk up to a tower to read its card (last commit, topics, open issues/PRs), then press **E** to open it on GitHub.
- **Tickers**: every tower scrolls its own latest commit message toward the street.
- **Roof**: painted in the repo's main language.
- **Named orbs**: each open issue/PR is its own orb tagged `#n`; grab it and the dispatch reads you the title.
- **You start inside this repo**: the game's own tower wears a crown, and you spawn at its door.

Controls: WASD / arrows to move, SPACE to jump, E to open the repo.

## How it stays live
CI runs `tools/fetch_repos.py` before every export, and also daily on a schedule, so the skyline tracks the repos. Only public repos are included. If GitHub is unreachable, the build uses the committed `data/repos.json` snapshot.

On `main`, the web build ships to itch.io via butler. That step needs the `BUTLER_CREDENTIALS` repo secret and the itch page `meshtool/godot-starter-3d`, and it skips cleanly if the secret is missing.

## Dev
`godot --path . -- --demo` runs attract mode: an autopilot drives to every orb, which serves as a smoke test of the full run.

Art and writing are original.
