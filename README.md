# SOLO / Mesh City

SOLO is Meshtool's original radio-robot road correspondent: bucket hat, amber glasses, orange tropical shirt and a bag for receipts. The public repo strip now uses warm stucco studios and roadside awnings.

Play with WASD/arrows, Space to jump, E to open the nearby public repo, M to toggle motion, R to restart. Calm motion is on by default. Desktop keyboard recommended. Collecting game orbs does not update real repositories or complete estate work.

## Build and verify

Godot 4.3 stable with matching export templates; Node 24 for delivery checks.

- Import: `godot --headless --editor --path . --import`
- Rendered smoke: `godot --path . -- --smoke-test`
- Delivery tests: `node --test tools/delivery.test.mjs`
- Portable web export: `godot --headless --path . --export-release "Web Portable" build/solo/game/index.html`
- Package the page and manifest: `node tools/package-solo.mjs`

The existing Web preset remains at main’s single-threaded setting. Web Portable disables threads so the same build can run on static hosts without SharedArrayBuffer headers. The existing GitHub workflow still exports the original preset until the SOLO release is reviewed.

The smoke command exercises real scene state but synthesizes collection events. It verifies the texture, repo world, player-only collection, duplicate collision guard, completion and motion toggle. It is not proof of genuine play. Godot's headless dummy renderer reports mesh teardown errors on this scene; the rendered smoke run is authoritative for this release.

## Once Everywhere

`tools/delivery.mjs` is a local delivery ledger, not an installed social API publisher. It reserves each release/destination/account before a send. A duplicate reservation never resends, including after an uncertain outcome. Record the public URL only after observing the published result. An unknown result requires reconciliation with the destination before any retry. A stale lock from an interrupted process also requires reconciliation. This provides conservative duplicate prevention; it does not promise provider-level exactly-once delivery.

Example: `node tools/delivery.mjs begin release/deliveries.json build/solo/manifest.json itch Meshtool`. Only if send=true, publish through the authorized destination; then run the same command with `receipt` and the observed HTTPS URL as the final argument. Use `unknown` plus a reason after ambiguous results.

Existing work: DevDesk #178 (distribution), #177 (signed replay proof). Signed Runtime gameplay receipts are not implemented in this pilot. Nothing is minted and no blockchain transaction is made.

## Source data and artwork

Only the committed public repo snapshot is included. The existing CI refreshes it via tools/fetch_repos.py. AI-generated original character art is in assets/solo/solo-v1.png. Created for RightOnPar LLC's Meshtool estate on 2026-11-15 with OpenAI image generation. No third-party character or logo is depicted.

## Preserved from main

Latest commit tickers, language-colored roofs, named issue/PR orbs, builder activity, commit bricks, PR rings and the aggregate DevDesk snapshot remain. The signal hub is a visualization of repo activity, not a live Runtime receipt stream. Calm motion suppresses the CI flashes and stale-queue blinking. Snapshot timestamps stay visible.
