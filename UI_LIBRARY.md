# Anime Origin UI

Run the main script from GitHub:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/aquapy1075-blip/animecardclashscript/main/cardorrigin.lua"))()
```

- `cardorrigin.lua`: gameplay controllers and profiles.
- `anime_origin_ui.lua`: window, tabs, controls and status display.

The main script loads the UI library directly from GitHub with
`loadstring(game:HttpGet(...))()`. No local UI file is required. The executor
must support `loadstring`, HTTPS access, and `game:HttpGet`. File APIs remain
optional for saving profiles. Update both files together when changing the UI
API. Advanced loaders may instead provide a compatible library table in
`getgenv().AnimeOriginUILibrary` before execution.

In Settings, use **Transparency** (0–65%) to change background transparency.
Text stays opaque for readability. This setting is saved with each profile.
The slider and window dragging support mouse and touch. Right Shift toggles
the window; the header buttons minimize or hide it without stopping automation.

The UI skips unchanged theme/control writes and skips cooldown rows on hidden
tabs. Hiding or minimizing the window suspends status rendering. Gameplay
controllers continue to use their existing scheduling and cooldowns.

Run the UI regression check with Python 3 and a standalone Luau executable:

```sh
LUAU_BIN=/path/to/luau python3 tests/test_ui_library.py
```

The check uses mock Roblox objects; visual appearance and executor integration
still need validation inside Roblox.

## Rift and game UI

Rift uses the captured `RiftGateEnterRequest`, `BuildRiftGateBattle(true)`,
`ReportRiftGateVictory` and `RiftGateLeave` flow. The native battle engine still
resolves combat; victory is reported only from its successful `onDone` callback.
Reward confirmation comes from `RiftGateReward`. Both admission and post-clear
waiting periods are five minutes, and an available Rift is still required.
Startup may read the native Rift popup for availability; it does not click or
modify that popup. A currently running native battle retains the shared combat
lock until it finishes, including after a timeout.

The script sends no virtual mouse or keyboard input. Raid uses direct button
signals and requires `firesignal`; its prompt requires `fireproximityprompt`.
Native battle rendering may still open or hide the game's battle UI. The library
only styles objects it creates. Its controls are not keyboard-selectable;
Settings → **RESET INPUT** clears stuck GUI selection for keyboard users.
Navigation preferences changed by that reset are restored when the script stops.

## Colosseum strategy

World HP/DMG blessings balance **selection counts** 1:1. With World's Favor,
equal picks produce different percentage totals (+15% HP versus +20% DMG).
Resuming an imbalanced run prioritizes the stat with fewer inferred selections.
Bench support priorities include the supplied support-card examples; duplicate
aura families are avoided. Draft rows constrain slots, so carry slot 2 is preferred
when the same carry is offered in that row, and supports are preferred in rows 3/4.
Dice can replace a weak back-slot card with a better support via the observed
`diceChoose {slot=...}` action. Arbitrary team swapping is not implemented: the
supplied Colosseum capture has no swap command, so its payload must be recorded.

To capture the missing swap payload: disable automation, run
`colo_remote_capture.lua`, manually swap two team positions in Colosseum, then
run `getgenv().ColoRemoteCapture.stop()`. Share `colo_remote_capture.json` from
the executor workspace. The recorder does not send requests itself.
