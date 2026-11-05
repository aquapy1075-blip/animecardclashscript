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
