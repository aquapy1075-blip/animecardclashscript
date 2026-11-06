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
Global GUI navigation and native selection are left untouched. Settings →
**RESET INPUT** only clears selection/focus belonging to this library. The window
background and shadow do not sink input. Touch devices have a separate **AO**
button to hide/show the window even while the main ScreenGui is disabled.

## Colosseum strategy

World HP/DMG blessings balance **selection counts** at **3 HP : 2 DMG**. With World's Favor,
equal picks produce different percentage totals (+15% HP versus +20% DMG).
Resuming an imbalanced run prioritizes the stat below its weighted target.
After the carry reaches eight People supports, Max-HP offers are assigned to
Hollow Harvester when present. Other offers in the same batch go to valid non-carry
teammates, respecting capacity, duplicate names and known lifeline restrictions.
Only full-batch assignments are submitted; if none fits, other blessing categories
remain available. No unverified skip sentinel is sent.
Bench support priorities include the supplied support-card examples; duplicate
aura families are avoided. Draft rows constrain slots, so carry slot 2 is preferred
when the same carry is offered in that row. Once one carry is secured, all three
remaining rows prefer distinct support cards over secondary carries when available.
Dice can replace the weakest non-carry slot with a better support (including a
third support at slot 1) via the observed
`diceChoose {slot=...}` action.

The supplied slot capture confirms `ColosseumRemote:InvokeServer("swap", {a=2,b=3})`
returns `ok=true` and the swapped server team in phase `ready`. Before each fight,
the controller puts the carry at slot 1 when all three other cards are supports
(supports at slots 2–4). Otherwise it puts the carry at slot 2. Remaining cards
are sorted by side priority with the strongest support furthest back. Draft searches
the four offer rows together and never picks duplicate base names, including
Mutated/Cursed variants. This also limits Goddess and Hollow Harvester to one each.
It sends at most one swap per tick, then uses the returned server snapshot for the
next decision. Missing/unchanged swap confirmation pauses automation for resync;
no local-only reordering is used. Existing wave-1 restart and stop-floor exits run
before arrangement. No existing API was changed.

## UI refresh: Cards, adaptive layout and feedback

Colosseum and Rift no longer show static Mode rows. Colosseum's **Cards** panel
shows four slots from the latest server team snapshot: gold **CARRY**, teal
**SUPPORT**, and normal theme text for other cards. Labels also identify roles
without relying only on color. Defeated cards show **DOWN**. Floor has its own
label. Card roles describe the existing strategy; displaying them does not
reorder cards or alter combat.

The UI adds a Light palette to the five existing themes. Window surfaces use
rounded corners, subtle strokes, a shadow and an accent gradient. Short,
cancellable TweenService transitions cover button hover/press, toggles, dropdown
opening, tab entrance, minimize and hide/show. Right Shift and the × button keep
their existing hide/show behavior; the Stop Script button now asks for confirmation.
Calling `state.stop()` directly still stops immediately.

On desktop, drag the lower-right handle to resize and drag the header to move.
The window stays within the viewport. Size and normalized position are saved in
the active JSON profile after an expanded-window drag/resize. Phone layouts use
a horizontal scrolling tab bar, stacked controls, four single-column card tiles
and readable unscaled labels. The library follows replacement cameras and viewport
changes. Hiding the UI cancels active pointer interactions and releases focus
only from its own text boxes.

Dropdowns now include a case-insensitive search field and a capped scrolling list.
Filtering preserves the original selected option index. Tooltips are available
on hover and long touch. Toasts support info, success, warning and error, queue up
to eight waiting messages, and resume pending feedback when the UI is shown.
Profile save/load/delete actions use the same existing profile functions.

### Compatibility

Existing contracts are unchanged: `Library.Version == 1`, `Library.Create(ctx)`,
`Repaint()`, `Refresh()` and `Root`. Existing main scripts can still create the UI
without the new optional context fields; old carry-only state falls back gracefully.
No existing function or parameter was renamed.

Two optional returned methods were added:

```lua
ui.Notify("Saved", "success", 3) -- kind: info/success/warning/error; seconds optional
ui.Destroy()                    -- destroys the UI; does not stop gameplay controllers
```

`Destroy()` is idempotent. It disconnects owned global listeners, cancels tweens,
invalidates delayed effects, releases dropdown listeners and destroys the owned
touch toggle. Recreating the library with the same state cleans
up the prior UI without chaining stop wrappers. All styling is scoped to objects
created by this library.

### Design comparison

These are design reference points, not a performance ranking or a claim of full
component parity. Library versions and forks differ.

| Reference | Familiar strength | This dashboard's implementation |
| --- | --- | --- |
| Rayfield | Clear controls and feedback | Consistent controls, hover/press feedback, searchable options and queued toasts |
| Fluent | Layered surfaces and theme hierarchy | Dark/Light palettes, shadow, translucent panels and short transitions |
| Orion | Simple tabs and sections | Existing sections/profiles with adaptive phone navigation and live team cards |

This library is tailored to the game's live team and automation state. Optional
components such as ColorPicker and multi-dropdown remain outside this iteration.
No FPS or memory benchmark against these libraries has been performed. Current
validation consists of Luau compilation and mock Roblox UI/controller tests;
visual appearance still needs confirmation in Roblox.

## Mini bosses with borders

Under **Multi-Boss → Mini Bosses**, enable **Auto Mini Boss**, select individual
mini bosses, and choose a border for each. This includes Cha Hae-In, Boothill,
Ragna, Guildmaster, Yuta, Sword Empress, Yuno and Sukuna from the new place.
The existing Auto Boss switch continues to control regular bosses independently.
Both sets share battle scheduling and take turns with Raid/Siege/Rift.

Each mini boss has independent selection and border profile flags. Display names
Normal/Calamity/Umbral/Astral/Paradox/Origin map to the game's internal
Normal/Gold/Rainbow/Uni/Astral/Origin keys. Server border progress determines the
highest unlocked border; the existing controller falls back to an unlocked tier.
Victory reports are sent only after a successful native battle result.

The new place contains the named mini-boss remotes and shared BossPanel code but
not the mini-specific caller configs. The controller therefore reads the actual
`id` from the native BossPanel open-event closure, using executor `getconnections`
and `debug.getupvalues` (or `getupvalues`). This bounded read does not hook, invoke
or open the native UI. Config IDs are cached; unavailable or mismatched configs
show **CONFIG NEEDED** and send no guessed cooldown/reward requests. A live-game
check is still needed to verify discovery on the user's executor.

Existing controller methods remain unchanged. `enableMini(on)` is an additive
method; Library.Create/Repaint/Refresh/Root and the GitHub loader are unchanged.

## Rare pull webhook

Settings → **Rare Pull Webhook · Base > 1B** polls the local player's
`EventRemotes.GetInventory` every ten seconds while enabled and configured.
The first successful response is a baseline: existing cards are not announced.
Later increases are reported regardless of acquisition source (roll, Inf, Colo, etc.).
Repeated snapshots and conversions between borders do not produce duplicate alerts.
Multiple new copies of the same card/border are grouped with a received count.
A gain consumed or removed before the next poll can be missed; source is not inferred.
It looks up `CardID` in `GameDatabase.CardDatabase` and checks `BaseRarity`.
Only denominators **strictly greater than 1,000,000,000** qualify. Exactly 1B does
not qualify. Borders are shown in the notification but never multiply this filter.
Several above-threshold entries in the supplied database are custom/admin cards;
normal rolls may produce few or no eligible events under this base-only setting.

Paste a Discord webhook URL in the input, click **SEND TEST** and
check **Webhook delivery**, then enable **Rare pull alerts**. Notifications include
the account name, card, base rarity, border, card ID and received count. Card artwork
is resolved through Roblox thumbnails to an HTTPS CDN URL when available; image
failures do not prevent text delivery. Messages are not copied from global chat. Mention parsing is disabled.
The watcher does not request rolls, hook remotes, scan UI, or listen to other
players' chat. No real Discord request was made during development tests.

The URL is saved automatically in `AnimeOriginV9/webhook.json` and restored on
restart when executor file APIs are available. It is plaintext: keep that file private.
The textbox clears after entry and the URL is excluded from shareable profiles.
If saving fails, delivery can still use the current session URL and status reports
that local saving is unavailable. **CLEAR URL** overwrites the saved URL with an
empty string so it does not return on restart. The enabled flag can be saved in profiles. **CLEAR URL** drops queued
messages for the old URL. Disabling the feature stops inventory polling and clears pending alerts;
stopping the script also clears the endpoint and pending queue.

Delivery uses executor `request`, `http_request` or `syn.request`, with native
HttpService as a fallback where available. The queue is bounded to ten messages,
spaces requests, and retries explicit HTTP 429 rate limits at most twice. Other
errors/timeouts are not automatically retried because delivery may be uncertain.
Raw transport errors and endpoint values are never printed in status/logs.
