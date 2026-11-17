# MeshTool AI Board Game — Godot handoff
Owner direction, updated 2026-11-17 (America/Los_Angeles):
**NO CHARACTER. Make it an AI board game with a human in the loop.**

This replaces the earlier character / roaming-city brief in full. Do not preserve SOLO as a player, avatar, NPC or on-screen mascot. Do not spend this pass polishing the existing walking/jumping game.

## Outcome
An attractive, playable, top-down AI operations board. The human sets the goal and makes decisions; AI agents propose and carry out approved moves; evidence changes the board. Use the captured MeshTool and DevDesk styling for the board, cards, paths and decision panels.

Project: https://github.com/Meshtool/godot-starter-3d
Continue the relevant work in PR #9 after checking its current branch. Reuse clean typography, licensed effects, replay/evidence utilities and existing data loading where useful. Its character, roaming and course direction is superseded by this request.
PR #5 has an older sea/orb design; borrow useful styling selectively. PR #6 contains conflicting brand work. Do not merge any whole competing redesign just to obtain colors.
Local checkout: C:\projects\godot-starter-3d
Local handoff: docs/visual-handoff-2026-11-17/
Observed checkout: feat/solo-release-v1 at 83506eee1093a1f9aaeaade4a2c0ebdaa194dece, with an existing modification to release/deliveries.json. Preserve it and implement in an isolated worktree.

## What the screen should contain
- **Center, most of the screen:** a legible node-and-path board with districts for DevDesk (plan/build), Runtime (run/verify), MeshMarket (package/list), and a receipt archive.
- **Mission cards:** the goal, completion criteria and progress; select a mission to highlight its route through the board.
- **Agent tokens:** abstract orbs, chips or card markers. These represent work or an agent turn, never humanoid characters.
- **Right decision panel:** the selected AI move, what it changes, destination, expected result and any known cost. Three clear actions: Approve move, Edit plan, Reject.
- **Top bar:** selected mission, Demo/Connected mode, AI turn or Your turn, and pause.
- **Bottom receipt tray:** ordered completed moves with timestamps and evidence links. A pending proposal is not a receipt.
- **Interaction:** mouse/touch selects nodes and cards; drag pans the board; zoom stays bounded; keyboard focus and Enter/Escape offer equivalent actions. Remove the avatar and WASD/jump instructions.

Keep it playful: cards flip to reveal capabilities and connections, paths illuminate as work advances, and completed objectives unlock visible board upgrades. Keep real execution outcomes determined by evidence, not random dice or decorative progress.

## One complete turn
1. Human chooses a mission card, for example: “Prepare a new game release.”
2. AI highlights a proposed route: Build → Test → Review → Publish.
3. AI proposes exactly the next move and explains its effect in plain language.
4. Board enters **Your turn / Awaiting approval**. The action does not execute while waiting.
5. Approve authorizes that specific move. Edit returns a revised proposal for a new decision. Reject cancels the proposal without advancing the board.
6. During execution show Running on that node and disable repeated submission of the same move.
7. The result is one of Completed, Failed, or Unknown. Record the actual outcome and evidence.
8. Completed advances the mission and adds its receipt. Failed stays visible with recovery options. Unknown waits for reconciliation; do not replay it blindly.
9. Pause/reopen resumes the same mission and pending decision. A retry must not produce another real-world action for an already completed move.

## Human-in-the-loop rules
- First playable slice uses explicit approval for each move so the loop is obvious.
- A changed proposal invalidates its previous approval.
- Public publishing, deployments, payments and access changes must use the existing authorization rails when connected. A visual click alone is not a new grant.
- No open-ended “approve everything” control in the first slice.
- Build a usable **Demo** board with simulated agents/actions if live connections are unavailable. Put Demo on the board and Simulated on its result cards.
- A **Connected** board can only use verified existing integrations. Display missing/stale connections honestly; do not build an additional memory, payment or receipt system for this visual conversion.
- Local replay match, simulated evidence and Runtime-signed verification stay distinct.
- Merely moving a token or collecting an on-screen reward never completes a real repository task.

## Reference map
| Image | Source | Transfer to the board |
|---|---|---|
| references/01_meshtool_home.jpg | https://meshtool.ai/ | Near-black field, blue atmosphere, restrained particle orbs, cyan/gold accents and bold typography. |
| references/02_devdesk_overview.jpg | https://devdesk.meshtool.ai/board | Clear heading, quiet panel surfaces, teal outlines, strong grouping. |
| references/03_devdesk_workflow.jpg | Same board, workflow section | The main composition reference: connected nodes, branching paths, status chips and distinct checks. |
| references/04_mesh_city_before.jpg | itch owner preview | Historical baseline only. This character/city layout is being replaced, not preserved. |

Actual browser captures, not proposed renders. Full DevDesk screenshots include the owner's working board: keep them local and do not commit or publish them as promotional artwork. Reuse visual styling, not operational text or counters.

## Art direction
Deep-ocean industrial board game. Dark steel panels, restrained teal light, gold decision/reward accents, fine path lines and a subtle slow lava backdrop. Clear hierarchy and empty space matter more than particles. The board itself is the star.

Suggested palette (recommendations, not extracted CSS):
| Role | Color |
|---|---|
| Ocean background | #050A12 |
| Board surface | #0D1824 |
| Panels | #101820 |
| Steel borders | #263442 |
| Active teal | #63D6C5 |
| Human decision / reward gold | #E9BD63 |
| Warm secondary accent | #E58A47 |
| Main text | #F2F4F7 |
| Secondary text | #A8B6C7 |

Use label + icon + color for state: Queued, AI planning, Your turn, Running, Completed, Failed, Unknown. Keep pending items calm; reserve red for actual failure. No chromatic splitting, grain, ink splats or full-screen distortion. Particle effects remain behind text and fade quickly. Offer reduced motion.

## First implementation slice
1. Replace the character/city entry scene with the board scene.
2. Build one board with 8–12 large nodes, a branching path, one mission, two abstract agent tokens, a decision card and a receipt tray.
3. Implement the complete proposal → human decision → running → result loop in labeled Demo mode.
4. Add edit/reject, pause/resume and duplicate-submit protection.
5. Apply this palette, typography, responsive layout and restrained animation.
6. Then map supported nodes to existing real integrations, keeping the same visible decision loop.

Reuse data/proof utilities from the existing project where appropriate. Remove player movement, jumping, collision-pickup goals and character UI from the new board experience. Do not maintain two conflicting main gameplay loops.

## Evidence and acceptance
- Screenshot the board at rest, an AI proposal waiting for approval, a rejected/edited move, a running move and a completed receipt.
- No character, character artwork, avatar controls, walking or jumping remains in the active board scene.
- Approval must be required before a move; edit/reject must not execute it.
- Repeated clicks, restart and reconnect cannot double-run a completed move.
- A failed or unknown move cannot appear Completed or earn a verified completion badge.
- Demo mode is unmistakable and never claims live integration or signed receipts.
- Validate the actual HTML5 build at 1280x720 and a narrow landscape size. Decision controls and receipt details stay on-screen.
- Report measured frame time/FPS on the Z13 browser. 60 fps is the target, not an untested claim.
- Return commit SHA, checks run and results, before/after screenshots, export artifact and remaining gaps.
- Use the installed toolchain and existing licensed assets. This handoff does not authorize a production merge, deployment or purchase.

## Receipt
Four reference screenshots captured and copied into the Godot project with matching SHA-256 hashes. The owner changed the concept to an AI board game with human approval, and this brief supersedes the earlier character-based direction. Implementation and gameplay verification remain pending.
