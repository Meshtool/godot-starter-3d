# Mesh City

The Meshtool estate as a deep-sea field of seat orbs, in the same look as runtime.meshtool.ai and meshtool.ai.

- **Every public repo is a particle orb.** Turquoise = Meshtool, gold = RightOnPar.
- **Size** = repo size. **Brightness** = how fresh the last push is. **Swirl** = commits this week.
- **The runtime** hangs in the middle, and every repo threads to it.
- **You are your own seat orb.** Fly to a repo to dock and read its card: description, last commit, who built it this week (Claude, Codex, Copilot, people), CI, and open issues. Press **E** to open it on GitHub. Dock every repo to finish.
- **DevDesk card**: the shape of the desk right now (how many items, how many being worked, how many waiting). Counts only, never titles.

Controls: WASD / arrows to fly, E to open the repo.

## How it stays live
CI runs `tools/fetch_repos.py` (public repos, last commit, open items, 7-day effort) and `tools/fetch_desk.py` (DevDesk queue shape from `vars.DEVDESK_EFFORT_URL`) before every export, plus daily. On any error it keeps the committed snapshots in `data/`.

On `main`, the web build ships to itch.io via butler (`BUTLER_CREDENTIALS` secret, page `meshtool/godot-starter-3d`).

## Dev
`godot --path . -- --demo` runs attract mode: an autopilot docks at every repo, which serves as a smoke test.
