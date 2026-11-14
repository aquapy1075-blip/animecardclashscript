# Skeleton Raid assist + auto-start (prototype)

Includes native-input auto-dodging, the user's captured Start action for Final difficulty, and automatic Ready. **Automatic Ready is now included** using the user's captured Pick/{1,2,3,4,5} action. It submits the five available indices once per raid after receiving both Deck options and the Pick phase. Dodging remains experimental and can fail.

## Start

Run skeleton_auto_dodge.lua outside a raid, near the native raid entrance. After two seconds it requests:
```lua
game:GetService("ReplicatedStorage").Shared.GuestRaids.Remotes.Lobby
    :FireServer("Start", "SkeletonBoss", "Final")
```

A received Phase confirms raid activity. Auto-start does not request again during known active phases or after Result until the server sends Closed. After Closed, it waits two seconds and requests the next Final run. Native minigame updates also mark an existing running dodge round active.

If no Phase confirms the request within 15 seconds, auto-start pauses instead of repeatedly sending requests. Check proximity/unlock conditions and retry explicitly:
```lua
print(getgenv().OriginSkeletonDodge.startRaid())
```

Stopping restores native movement/update methods and stops further start requests; it does not cancel a native raid already running:
```lua
getgenv().OriginSkeletonDodge.stop()
```

Inspect state, result, waitingStart and attempt count:
```lua
print(getgenv().OriginSkeletonDodge.status())
```

## Early-jump correction

Blue-heart planning now evaluates wait/no-jump and jump delays of 0–0.5 seconds, with short/long holds, over a one-second horizon. Its movement candidates are tangent to gravity, so a direction cannot inadvertently trigger a jump. Blue vertical centering was removed because it rewarded unnecessary early jumps. Native input jump-buffer state is included in prediction. Red-heart movement retains its shorter horizon.

This remains heuristic dodging: damage is possible. The planner does not fully model future unspawned hazards, moving boxes or all mobile transformations. Keep the raid screen active and avoid simultaneous manual movement while testing.

## How it works

Loads Shared.SkeletonRaid.Config and DodgeBox. Movement is chosen through native input.stick/input.btnJump and the original method still processes physics/collisions. Native update time is used for hazard prediction. HP, invulnerability, hit counters, timers and reward/result messages are not modified. No namecall/remote interception is used.

The inbound log contains 99 records without dropped messages/errors, including a full Judgment win (Phase rounds 1–5 → Victory → Result.data.won=true → Closed). The following Final run is captured only up to Pick. Judgment took about 218.5 seconds, so this does not establish faster-than-AFK clears.

## Validation

Syntax and synthetic checks passed for white/blue/orange hazard rules, beam escape, gravity jumps, native timing/forwarding, stop restoration, no idle blue jumps, waiting for an approaching bone row and avoiding it through the complete jump/landing simulation.

Auto-start mocks verify the exact Start/SkeletonBoss/Final payload, no requests during known active phases/results, replay only after Closed, pause on an unconfirmed request and no starts after Stop. No live Roblox survival, timing or server admission test has been performed.


## Automatic Ready

When SkeletonRaid sends Deck, cache its options. When the server's Phase becomes Pick, verify that all five provided indices 1–5 exist, then send the exact captured request once:
```lua
game:GetService("ReplicatedStorage").Shared.Net.RemoteObjects.SkeletonRaid
    :FireServer("Pick", {1,2,3,4,5})
```

Deck-before-Pick and Pick-before-Deck ordering are supported. Repeated messages do not duplicate the request. A new Prepare (seed/startAt) or new Start request resets the per-raid guard. Take indicates selection is complete. Missing indices do not trigger a guessed selection, and Stop prevents further Ready requests.

status() includes autoReady, pickSent, pickAttempts, readyConfirmed and readyStatus. Auto Ready is ON by default.

Tests passed for the exact payload, event ordering, duplicate events, missing slots, new-run reset, Take confirmation and Stop. Replaying the uploaded Judgment → Final phase log produces exactly two Ready requests, one per run. Live server Ready handling remains untested.
