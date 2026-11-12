# Anime Origin V11

## Use

After loading the updated script, open **Settings → Connection**:

- **Auto Execute after teleport** queues the loader for the next teleport/server hop. It requires the executor's queue-on-teleport API plus `readfile`/`writefile`. The status row reports unsupported APIs or failed local writes. OFF is checked again by the queued bootstrap in the destination server.
- **Auto Reconnect** tries disconnects, kicks, account-in-another-session errors, and failed teleports. Retries back off over 8/16/32/60 seconds, with up to eight attempts per incident. REJOIN resets the budget for a manual retry. Roblox can reject admission; a request being accepted does not establish a completed reconnect.
- Every reconnect attempt uses the **saved Settings webhook**, independently of the rare-card notification toggle. Messages distinguish attempts, teleport initialization failures, and script arrival after reconnect. Messages are best effort: a dead network or executor process cannot deliver HTTP. Arrival notifications require Auto Execute and the saved webhook to be available in the destination session.

No webhook token is embedded in the teleport queue. Settings and the existing locally stored webhook are restored by the destination script. Another ordinary player entering the server is not a disconnect trigger.

For testing this PR before merge, use the branch loader below. It keeps the same source URL for subsequent hops:

```lua
local source = 'https://raw.githubusercontent.com/aquapy1075-blip/animecardclashscript/codex/origin-v11-stability-minimal-ui/cardorrigin.lua'
getgenv().AnimeOriginScriptURL = source
loadstring(game:HttpGet(source))()
```

After merge, the usual `main/cardorrigin.lua` loader works. Clear `getgenv().AnimeOriginScriptURL` when switching from this preview loader to main in the same executor session. Keep the preview branch if you continue using its loader.

## Changes

- Guard Boss, Siege, Rift, and Colosseum work against OFF/ON generations and script restarts.
- Bound client RPC waits to 20 seconds. Keep one pending flight per remote across re-execution; late results cannot restart a stopped controller or send duplicate in-flight requests. This cannot cancel a request already accepted by the server. Uncertain Colosseum mutations pause and require resynchronization.
- Bound queue admission and release abandoned/error-path leases. Ignore stale battle callbacks. Recheck Siege slots after queue acquisition.
- Check webhook generation immediately before POST, capture its destination, prioritize queued notifications over inventory polling, and serialize workers.
- Pin the UI dependency to an immutable commit and check its build alongside its API version.
- Keep the UI minimal: no per-mode banners or large titles; quiet surfaces, restrained accent, compact metrics, readable switches, and compact phone toggles. Existing themes, search dropdowns, profiles, drag/resize, and Right Shift remain available.

## Validation

Compile both Lua sources with `luau-compile`. Run all tests with a Luau CLI on PATH:

```sh
for test in tests/test_*.py; do python "$test" || exit 1; done
```

11 suites pass, including deterministic yielding/cancellation tests that execute the real remote/queue helpers and actual Boss/Siege launch functions. Other tests cover Colosseum strategy, Rift, webhook destination changes during thumbnail resolution, reconnect backoff, duplicate/OFF bootstrap gates, and UI compatibility/responsiveness/cleanup.

Validation uses mocked Roblox APIs and local browser layout previews. Live Roblox/executor reconnect and teleport behavior still needs an in-game check. No gameplay remotes or Discord webhooks were invoked during validation. Superdesign was requested but its tools/skill were not exposed to this session; the UI was implemented directly in Roblox Lua.
