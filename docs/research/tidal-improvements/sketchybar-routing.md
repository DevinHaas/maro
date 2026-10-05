# Connect SketchyBar to the current Maro installation

Read-only investigation, 2026-10-04, source checkpoint `32ccc9a`. No installation, configuration, playback, process termination, or app-source changes performed.

## Confirmed cause and actual route

The new Tidal build was deliberately launched as an isolated second app. SketchyBar still correctly addresses the older managed installation. This is an installation/routing mismatch, not evidence that clicking selects an arbitrary app by bundle name.

- `~/.config/sketchybar/sketchybarrc:113` sources `/Users/devinhasler/Applications/Maro Local/sketchybar/maro.sh`.
- Installed `sketchybar/maro.sh:2–3` sets `MAROCTL` to that installation's `bin/maroctl` and runs its plugin.
- Live read-only `sketchybar --query` of **both** `maro.anchor` and visible `maro.anchor.notched` confirms their stored click commands invoke installed `sketchybar/maro.py click`, with `MAROCTL=/Users/devinhasler/Applications/Maro Local/bin/maroctl`; neither contains a `MARO_SOCKET` override. The notched anchor reports drawing on.
- Installed `bin/maroctl:2–3` exports `MARO_APP_BUNDLE=/Users/devinhasler/Applications/Maro Local/Maro.app` and executes that bundle's CLI. These are regular files; `~/.local/bin/maroctl` does not exist and is not involved.
- Plugin `integrations/sketchybar/plugins/maro.py:50–60,137–139` runs `status`, then `player` when a track is loaded, otherwise `search`. `MARO_SOCKET`, when supplied, becomes `--socket`; otherwise `CommandClient.swift:42–44` selects `~/Library/Application Support/Maro/maro.sock`.
- The CLI sends to the existing socket first. Only missing/refused connections trigger recovery (`CommandClient.swift:17–38`). Recovery selects the wrapper's explicit bundle path, passing the socket's parent as `MARO_DATA_DIRECTORY` (`MaroCLI.swift:46–64`). Changing the launch path alone cannot redirect an already-running service.
- Process inspection confirms installed PID **84785** and isolated build PID **29411**, each running its respective `Maro.app/Contents/MacOS/Maro`. Both sockets exist. App executable SHA-256 values differ; both bundles nevertheless declare `local.maro.player.development` / `dev-3`, so bundle version is insufficient proof of upgrade.
- `.build/local-tidal-32ccc9a/Launch Tidal.command:2–4` explicitly opens the test app with its own `data/` directory and `MARO_SKETCHYBAR=/usr/bin/true`. That disables its bar notifications (`MaroApp.swift:74`, `BarNotifier.swift:31–35`) as intended.

## Blocking prerequisite: valid CLI responses

Fresh probes used each bundle's CLI with its explicit existing socket, removed `MARO_APP_BUNDLE`, and bounded execution to ten seconds; recovery was disabled and no playback/window command was sent. Installed app: exit **0**, valid JSON, `ok=true`, paused. New test app: exit **75**, zero stdout, “Maro did not return a valid response.” This independently reproduces the build-note observation. Because a click starts with `status`, changing paths now would fail before presenting either window.

**Strong source-backed hypothesis, not yet runtime-proven cause:** Home discovery adds up to 60 metadata artwork identities (`MaroController.swift:193–201,764–780`). `snapshot` exports all existing artwork paths (`:84–95`), but `CommandResponse.validate` only allows identities from favorites or the loaded track (`CommandProtocol.swift:119–125`). A cached recommendation outside that set therefore violates the wire contract. The server validates before writing and silently closes on failure (`CommandService.swift:37–48`); the client maps read/decode failures to outcome-unknown (`CommandClient.swift:64–70`). This fits exit 75. Do not broadly relax path validation without defining the intended contract.

A separate build-note failure concerns the lifecycle test's “worker initializes lazily” assertion (`scripts/check-app-lifecycle.py:76–84`). Startup now presents Home, whose discovery invokes metadata searches (`HomeRecommendations.swift:83–91`). Reconcile that expected behavior rather than claiming the lifecycle gate passed.

## Proposed implementation tickets and order

1. **Repair and regress CLI status after discovery.** Decide whether command responses filter artwork to loaded/favorite identities while native snapshots retain recommendation artwork (preferred narrow fix), or formally expand the wire contract. Test status before/after cached discovery, arbitrary metadata IDs, favorites changes, and selected-track changes. Preserve filename/path and identity validation; verify action replies remain valid and lost replies never replay mutations. Add offline deterministic fixtures to controller/protocol/service coverage.
2. **Promote a verified standalone build into the existing managed prefix.** First reconcile lifecycle expectations and run appropriate isolated checks. After approval in the implementation session, gracefully stop both known app instances; wait for shutdown/state flush. Back up canonical and isolated state separately, excluding socket/lock artifacts. Default to retaining canonical `~/Library/Application Support/Maro/state.json`; review whether newer isolated favorites/resume position should be migrated. Do not overwrite one with the other implicitly. Keep the existing `Maro.YouTube` Keychain account (`PlaylistLibrary.swift:53–54`).
3. Run `scripts/install.py install --app <verified-bundle> --prefix '/Users/devinhasler/Applications/Maro Local'`. Existing receipt currently verifies. Installer checks signature, copies matching CLI/plugin, and retains a rollback backup (`install.py:65–101`); it does not touch canonical state. Keep the existing config source block. Start the installed app against canonical state with normal bar notifications; re-register its item or reload normally if needed. Avoid permanent references to `.build`.

## Acceptance and review choices

Verify process executable path/hash, single canonical socket owner, installed wrapper, both stored click scripts, and valid status after Home artwork loads. Clicking with a loaded track toggles the new native card; empty state opens the new library. Check notifier-driven label updates, paused restoration, preserved favorites/account, and quit/recovery using the same installed bundle. Retain rollback evidence. `check-live-bar.py:30` refuses existing Maro items: do not run it against this configured bar or remove those items merely to satisfy it.

Review choices: canonical-versus-isolated state precedence; narrow CLI artwork filtering versus protocol expansion; expected worker startup behavior. Card styling is an independent ticket. Routing cutover depends on valid status and verified packaging.
