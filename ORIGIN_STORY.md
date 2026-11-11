# Origin Story (draft)

UI adapted from `anime_origin_ui.lua`, upstream blob `543f7f2b12f690f6b6592dcf10d805807fe2c29b`. The standalone file embeds the adapted UI and adds searchable multi-select controls. Existing gameplay scripts and upstream UI are unchanged.

## Current limitation

**Fully automatic progression is not implemented for the live game yet.** The uploaded place exposes BattleState/BattleEvent remotes but does not contain their server handlers or a verified completion payload. This draft starts encounters using the supplied StartEncounter request, then waits for manual confirmation or a separately configured verified adapter. It does not guess completion based on elapsed time, report victories to the server, turn on the game's combat AUTO, teleport between maps, or bypass unlock conditions.

## Try the draft

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/aquapy1075-blip/animecardclashscript/codex/origin-story-ui-draft/origin_story.lua"))()
```

Requires a Roblox client executor supporting loadstring and game:HttpGet for this loader. The standalone script itself does not download more code.

1. Story → Maps: choose one or more maps.
2. Mob / Boss: choose one or more encounters.
3. Each selected target on a selected map reveals its own multi-select difficulty control; Easy is selected initially. Deselect Easy if unwanted.
4. PREVIEW lists the exact order. Maps follow story order; targets follow route order within a map; difficulties follow Easy, Medium, Hard, Impossible, Cosmic. All selected difficulties for one target run before moving to the next target.
5. START sends the first request. Enable the game's combat AUTO yourself if needed.
6. Until the adapter is implemented, click CONFIRM WIN only after that fight actually ends in victory. CONFIRM LOSS stops the run. These buttons advance/stop the local queue only.
7. STOP stops scheduling; the current native battle continues. After it ends, CLEAR BATTLE allows a fresh run.
8. Repeat whole queue is off initially. Losses, explicit start rejection, request errors and a 15-minute result timeout stop the run.

Selections are session-only. Queue selections are snapshotted at START; edits apply to the next run. Repeat applies to that same queue. Right Shift or the mobile AO button hides/shows the UI.

## Capture the missing protocol

Run the script before starting a battle. After the battle ends, press COPY CAPTURE and share the captured BattleState/BattleEvent/StartResponse payloads. With no clipboard API, it writes OriginStory-capture.json when writefile exists, otherwise prints to the console. Capture stores only the latest 60 received messages, with bounded depth/size. It makes no network upload.

## Verified adapter extension

Set `getgenv().OriginStoryBattleAdapter` to a function taking `(source, packedArgs, currentQueueItem)`. Source is BattleState, BattleEvent, or StartResponse. It should return nil for unrelated messages, or a normalized table:

- Start: `{phase="started", id=actualBattleId, cardId=actualCardId, difficulty=actualDifficulty}`
- Finish: `{phase="finished", id=actualBattleId, cardId=actualCardId, difficulty=actualDifficulty, won=actualBoolean}`
- Rejection: `{phase="rejected", cardId=actualCardId, difficulty=actualDifficulty, reason=actualReason}`

These names are an internal adapter contract, **not a claim about the game's payload schema**. Implement mappings only after inspecting live payloads. Finish requires a matching battle ID and target/difficulty. Unknown/stale results do not advance.

## Validation

Full standalone file passed Lua 5.4 syntax compilation. Mock tests checked queue ordering, selected-map filtering, empty mode selection, all 180 target/difficulty pairs, boss markers, manual progression gating, loss/stop/restart, explicit rejection, verified adapter progression and stale battle-ID rejection. Roblox visuals, executor integration, unlocked target admission and real battle completion remain untested.
