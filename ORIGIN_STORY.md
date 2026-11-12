# Origin Story

Standalone Roblox Story UI adapted from anime_origin_ui.lua. Multi-select maps/targets, per-target difficulties, searchable dropdowns preserving scroll, theme-aware selected surfaces without tick marks, multicolor accents and Config profiles.

## Run

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/aquapy1075-blip/animecardclashscript/codex/origin-story-ui-draft/origin_story.lua"))()
```

Select maps, then mob/boss options limited to those maps. Select difficulties independently per target (Easy initially selected). PREVIEW shows map → encounter → difficulty order. Auto Story ON snapshots selections; OFF stops scheduling. The toggle reflects actual running state and turns off at completion/errors. Default is one pass. Native game AUTO should be enabled where needed. Right Shift or mobile AO toggles the UI.

## Verified server combat/results

**ShowBattle, ShowBattle2 and BattleRewards are no longer used.**

The user's passive capture contains simultaneous Tower and Story traffic. For example:
- Tower: BattleEvent type BattleEnd, lane 2, won true, battleId 11042356355-1507268926.
- Story: BattleEvent type BattleEnd, lane 1, won true, difficulty Easy, battleId 11042356355-1512618733.

StartEncounter admission is anchored to its returned tuple: successful pcall, admission true, nil, and a fresh active snapshot containing battleId, lane and the matching enemy portrait cardId. Each request owns its own tracker.

Only a BattleEnd with the admitted battleId is accepted. Lane and difficulty, when present, must also match. A boolean won=true advances to the next selected entry. won=false retries the same entry after three seconds. Other battle IDs, including concurrent Tower floors, are ignored.

The listener is connected before sending requests. Early BattleEnd events are buffered by ID until the admission tuple returns, so short fights are not missed. UI visibility does not affect tracking. STOP invalidates the worker; requests are never overlapped. Unknown admission or a missing matching result stops without inventing victory/loss or repeatedly starting an untracked fight. Admission waits at most 30 seconds; result waits at most 15 minutes. The final matching victory completes a one-pass queue.

COPY CAPTURE exports bounded StartRequest, StartResponse, StoryAdmitted, BattleEnd and BattleResult diagnostics locally. No log upload is performed.

## Config

Config supports SAVE, LOAD, DELETE and SET AUTO LOAD. Profiles include map/target selections, independent difficulties, repeat flag, theme, transparency and window geometry.

Files are OriginStory/<name>.json and OriginStory/index.json in executor storage. Names allow 1–48 letters/numbers/spaces/underscores/hyphens. Persistence requires readfile/writefile/isfile/makefolder; deletion requires delfile. Auto Load restores settings and saved mode toggles. Loading stops old mode workers and waits for outstanding work before applying the new settings.

## Validation and limitations

Full script syntax and queue checks passed. Replayed both actual uploaded BattleEnd examples to verify that Tower wins do not advance Story and the matching Story win does. Mock tests cover result-before-admission races, stale IDs, lane/difficulty mismatch, synthetic won=false retries, final-win completion and Stop. The mock has no combat GUI objects, proving that those objects are not required by the new controller.

The provided capture contains wins but no explicit won=false event; false handling is tested synthetically. Live Roblox integration remains untested. This does not change combat decisions, bypass unlocks or teleport between maps; native travel may be needed.

## Notification and stop diagnostics

Per-fight Starting/WIN/LOSS messages update the live Story Status and Last server result rows only; they are not queued as corner toasts. Start/Stop clear old toasts, hidden toasts are discarded rather than replayed, and pending notifications expire after six seconds. A final completion toast identifies the selected count and last encounter.

COPY CAPTURE now includes current status, last result, running state, current item, index and queue size. QueueStarted records selections, QueueCompleted explicitly records successful exhaustion of the selected queue, and QueueStopped records the reason. Routine unrelated Tower completions are no longer logged repeatedly, preserving space for relevant Story records.

The user's later capture shows nine matching server wins through FirstDemon/Hard, but lacks a completion/stop record. It does not establish a loss or explain any later stop. The prior UI retained and replayed notifications when hidden, which can make old WIN messages appear after combat has stopped. This revision fixes that independently of server result handling. Mock tests assert no per-fight WIN/LOSS toast, clearing on Start/Stop, and completion text containing the queue size. Live-game behavior is still to be checked.

## Gradient text and transparency slider

Bold headings and control labels use a violet → blue → mint text gradient. Dark themes use bright colors and Light uses darker colors for readability; the dark Story hero retains the brighter palette. Body copy and live values stay plain. Text gradients update when switching themes.

Dropdown choices use selected background/text colors only, with no tick badge or ASCII checkbox. Selection still updates in place and preserves scroll.

Settings → Transparency is now a mouse/touch slider from 0 to 65%, with a gradient fill, thumb and numeric percentage. It uses AO_UI_Transparency, preserving existing profile compatibility and the upper limit for readable surfaces. The shared input lifecycle cancels dragging when the window hides. Slider endpoint, midpoint, clamping and zero-width guard checks passed, along with script compilation and server controller regression checks. Roblox rendering and physical input still need a live-game check.

## Auto Skill Tree

The uploaded place contains 16 nodes in ReplicatedStorage.Shared.Config.SkillDefinitions. The new Skill Tree tab lists all nodes, max ranks and prerequisites. Select multiple skills, choose Purchase or PurchaseMax, set a 1–10-second request interval, and the Auto Skill Tree toggle. Its OFF state stops upgrades independently of Story; UNLOAD stops all modes. Settings are saved in Config, but Auto Load restores the saved Auto Skill toggle and starts purchases only when that saved toggle is ON.

Uses the user's supplied SkillAction:InvokeServer("Purchase" or "PurchaseMax", skillId). Requests are sequential, at least one second apart; errors stop the worker. Server funds, locks and caps still apply. Responses are logged as SkillResponse and SkillResult; request success is not invented from pcall success.

Rank synchronization reads validated numeric profile.skills values from ProfileSync. The skills property is referenced by TitleConfig in the place, but the live ProfileSync envelope has not been captured. A RequestSync event is requested once at START where available. Confirmed ranks let the scheduler skip capped nodes and stop once selected goals are reached. Without a recognized rank snapshot, selected-only mode can still send the supplied purchase requests and reports ranks as unconfirmed.

Optional Auto prerequisites spends coins on dependencies and requires confirmed ranks. It waits without spending if rank data is unavailable. It purchases prerequisites one rank at a time up to their required thresholds; PurchaseMax applies only to explicitly selected nodes. Selected nodes themselves target their definition's maximum rank. Selection is snapshotted at START; restart after changing selected targets.

| Skill ID | Max rank | Requires |
| --- | ---: | --- |
| Awakening | 1 | None |
| LuckBoost | 1000 | Awakening 1 |
| SwiftHands | 1500 | Awakening 1 |
| BorderChance | 100 | Awakening 1 |
| BattleSpeed1 | 1 | Awakening 1 |
| FortuneFlow | 250 | LuckBoost 100 |
| CoinAffinity | 1000 | LuckBoost 50 + SwiftHands 200 |
| RapidDraw | 1000 | SwiftHands 350 |
| BossChance | 100 | BorderChance 25 |
| BattleSpeed2 | 1 | BattleSpeed1 1 |
| Windwalker | 1000 | RapidDraw 400 + CoinAffinity 300 |
| PotionDuration | 100 | BossChance 25 |
| BattleSpeed3 | 1 | BattleSpeed2 1 |
| ElderAscension | 1 | FortuneFlow 100 + Windwalker 400 + PotionDuration 100 |
| BattleSpeed4 | 1 | BattleSpeed3 1 |
| TwinBattle | 1 | BattleSpeed4 1 |

Coin Affinity example: Awakening 1, Luck Boost 50, Swift Hands 200, then Coin Affinity. Windwalker crosses Rapid Draw 400 and Coin Affinity 300. Elder Ascension requires Fortune Flow 100, Windwalker 400 and Potion Duration 100. Battle Speed I–IV lead to Twin Battle.

Checks passed for all 16 definitions, prerequisite thresholds/chains, confirmed caps, unknown-rank spending guard, single-rank prerequisite purchases versus selected PurchaseMax, and Stop/restart worker invalidation. Existing Story server-protocol regression checks still pass. Live SkillAction/SkillResult/ProfileSync integration remains untested; COPY CAPTURE contains skill request/response diagnostics.

## Higher or Lower

The new Higher or Lower tab uses an ON/OFF toggle, live status, streak and loaded stat-entry count. Restart after game ends defaults OFF and is stored in Config. Stand near the native Higher or Lower activity where the server requires it; the script does not teleport or bypass proximity checks. Avoid manually submitting guesses while Auto Higher or Lower is running.

From HigherLowerConfig and HubHigherLower in the uploaded place:
- Compare total DMG + HP at level 0.
- Card keys include identity and border: cardId|variant.
- HigherLowerConfig.pool() computes the eligible pool using CardStats.compute(id,variant,0), excludes summonOnly and restricts evolve/legend cards to their proper variants.
- entry(key) gives the exact eligible card stats, including the right card whose stats are hidden by the native UI.
- start returns admission boolean and a run with round, a, b.
- guess uses {guess="higher" or "lower", round=run.round}.
- Successful ongoing responses provide correct, b, next, nextRound and streak; ended terminates a run.
- HigherLowerEvent type ended handles server termination (for example timeout/away).

The automation loads/prewarms the live config pool before starting. It compares exact entry totals, waits at least 1.1 seconds between guesses and advances only using server nextRound. Unknown keys, equal totals, visible-stat mismatches, malformed/stale rounds, rejected requests or lookup errors stop instead of guessing. It never sends a guessed victory/reward claim. Native server results and milestone rewards remain authoritative.

Turning OFF stops future guesses and uses the native quit action for its active session after any pending request returns. Start is blocked until cleanup completes, preventing an old worker from quitting a new session. Reloading is blocked while a Higher or Lower worker is still active; turn it off and wait for cleanup first.

Tests passed for variant-aware totals, higher/lower/higher rounds, equal/unknown/mismatched stats, server round advancement, request spacing, completed sessions, server-ended events, and Stop/restart cleanup. Story and skill regression tests passed. Live-game requests and actual pool contents still require verification in Roblox. COPY CAPTURE includes HigherLowerGuess, HigherLowerResponse and HigherLowerEnded records.


## Unified mode toggles and persisted execution state

Story, Auto Skill Tree and Higher or Lower each use one ON/OFF toggle. Separate Skill Tree START/STOP buttons are removed.

SAVE synchronizes actual current worker states into StoryRunning, SkillRunning and HLRunning, then writes those booleans with settings. LOAD restores both ON and OFF and applies them to actual workers. SET AUTO LOAD causes the next execution to restore selections/settings, build the UI/controllers, then start each mode saved ON. This includes selected skill purchases when Auto Skill Tree was saved ON. Older profiles missing a toggle key default that mode OFF.

To persist a mode ON: configure it, turn it ON, SAVE, then SET AUTO LOAD for that profile. To change the saved state to OFF, turn it OFF and SAVE again. Finishing a queue turns its live toggle OFF but does not silently overwrite the saved profile.

Manual LOAD first reads/validates the profile, stops existing mode scheduling, and waits for pending requests / Higher or Lower cleanup. If the new profile enables Story, it also waits for a currently tracked Story fight to end. After 30 seconds still waiting, the load aborts without applying new selections; load again after outstanding work ends. Tracked results are still received while Story scheduling is OFF. Parallel profile loads and edits during profile transitions are blocked.

Mocks verified all three ON/OFF states, actual-state saves even before the repaint loop runs, loading an OFF profile while workers are active, restoring an ON profile, deferred startup auto-load, and legacy OFF defaults. Story, skills and Higher or Lower regression checks still pass. Live Roblox/executor file behavior remains untested.


## Monitor tab: raid currency and server Domain

Monitor shows:
- Bone Tokens (Skeleton Raid), taken from ProfileSync.currency.boneTokens or the captured SkeletonRaid Result.data.total.
- Net balance change since the first known balance this script session. Spending is subtracted; this is not gross raid earnings.
- Net hourly rate after at least 60 seconds, last balance-update age and a session-baseline RESET.
- War Coins separately, from ProfileSync.currency.warCoins.
- Current Domain name, countdown, luck bonus and opener. The uploaded place exposes Domain rather than a separate weather system, so this panel is explicitly labelled Server Domain.

Domain reads only ReplicatedStorage DomainId / DomainEndsAt / DomainBy attributes, resolves metadata using Shared.Config.DomainConfig.get and counts down against workspace:GetServerTimeNow, matching the native DomainConfig.active logic. Unknown IDs retain their raw name; expired/missing Domain attributes show no active domain. No weather is inferred from Lighting colors.

Currency starts as Waiting for sync rather than an invented zero. REFRESH sends the native RequestSync event, limited to once per five seconds. Profile/result listeners stay connected while other tabs are selected; visible monitor values refresh roughly twice per second. Unrecognized ProfileSync envelopes produce a small MonitorSyncShape diagnostic for COPY CAPTURE. No gameplay purchase or reward claim is sent.

Tests passed for profile/raid total synchronization, session spending, invalid/unknown balances, Domain countdown/expiry and unknown IDs, reset and sync throttling. Story, skill, Higher or Lower and mode-profile regression checks also passed. Actual server ProfileSync envelope and live rendering remain untested.

## Rare Domain webhook

Monitor → Rare Domain webhook accepts a Discord webhook URL, an alerts toggle, an optional Domain Clash toggle, SEND TEST, CLEAR URL and delivery status/counters. Paste the URL and leave the field to validate it; the field clears and displays a saved placeholder. SAVE stores WeatherWebhookURL, WeatherWebhookEnabled and WeatherWebhookClash in the selected local Config profile. LOAD and Auto Load restore them; alerts saved ON resume automatically. The URL is stored in plain text in the executor profile, so remove it before sharing that profile.

The watcher runs independently of visible tabs or window rendering. It reads the live DomainConfig.Order/Data positive weights to identify the rarest random Domain, including ties. In the uploaded place Infinite Void has weight 0.1 out of 100 (0.1%). Domain Clash has weight zero and is a separate scheduled event; its optional notification is enabled by default.

Only active DomainId/DomainEndsAt occurrences are eligible. Each server occurrence is marked before sending and retained in getgenv across script re-execution, so duration extensions, toggle off/on and re-running the script do not repeat alerts to the same URL. Changing the destination allows the current occurrence to notify the new URL. An expired or changed Domain starts a new occurrence. The script must remain running in that server to observe events.

Notifications include Domain name, rarity, remaining duration, luck boost and server ID/join link. SEND TEST explicitly sends a labelled test even with alerts OFF. Only HTTPS Discord webhook endpoints are accepted. Delivery uses the executor request/http_request/syn.request API, with a five-second request gap. HTTP 429 retries twice with bounded backoff; transport/other HTTP errors report failure without repeated automatic sends for the occurrence. Disabling alerts or unloading cancels queued automatic retries. An HTTP request already sent cannot be recalled.

All HTTP calls in validation were mocked; no real webhook was contacted. Checks cover URL validation, rarity/ties, common-domain silence, new occurrences, extension/re-execution deduplication, destination replacement, manual test, Clash opt-in, success/failure counts, rate-limit retries, cancellation and Config persistence/legacy defaults. Existing Story, Skill Tree, Higher or Lower and Monitor checks also pass. Actual Discord delivery and executor UI need an in-game check.

## Active Rules: per-card conditional GuestActive

The Active Rules tab discovers ability-bearing cards from BattleState.guestActives. During an active battle the card picker lists only that selected lane's ability cards. Before a snapshot is available, it offers previously discovered/saved cards and SCP3008. Each discovered card starts with its rule OFF; this avoids spending abilities before a condition is configured. First receive a combat snapshot to populate the deck's ability list.

Choose battle lane 1 or 2 and enable conditional actives globally. Pick each card, enable its rule, and choose one condition:
- Combat start: requires an observed fresh/round-1 battle and fires only while round is at most 1. Enabling it midway does not count as combat start.
- Low HP: use the 1–99% mouse/touch slider. HP target slot 0 means any living allied card, including cards in hand; slots 1–5 select the deck slot. HP must be strictly below the threshold; dead or unknown-HP cards do not trigger.
- Round: use at the chosen round or later, once the ability becomes available. The round input is clamped to 1–999.

Example: pick SCP3008 → enable this card rule → Low HP → target slot 2 → 50%. Then enable conditional actives. The SCP3008 No Exit implementation heals all living allies to full; it also retains its native location/status effects. Other ability cards can independently use Combat start or Round rules. The game’s own automatic active-use feature must be turned OFF manually so it does not consume an ability ahead of these rules.

The controller reads full BattleState snapshots and updates HP/rounds using matching Damage, Heal, Stat, Revive, Death and RoundStart events. Conditions use server HP rather than GUI visibility. Each request is exactly BattleAction:InvokeServer("GuestActive", {cardId=..., battleId=currentBattleId, lane=selectedLane}), matching the user's supplied payload. An available ability and living, unsuppressed caster are required. Ended/superseded IDs and mismatched lane events are ignored; stale battle data waits for a fresh update.

This version attempts each card at most once per battle, including abilities that might have a native cooldown. Attempts are recorded before yielding and retained across re-execution, with bounded history. Native/manual GuestActive events also suppress duplicate requests. Rejected/uncertain calls are logged without automatic retries. Requests are at least one second apart and do not overlap Story admission; Story waits for an outstanding active request before another admission. Disabling the global toggle stops future requests; an already-sent InvokeServer cannot be cancelled.

Config SAVE/LOAD/Auto Load preserve the global toggle, selected lane/card and independent per-card rule settings. Legacy profiles default conditional actives OFF. Profile loading waits for outstanding active requests. UNLOAD disconnects the listeners and stops the watcher. COPY CAPTURE includes ActiveRuleRequest and ActiveRuleResponse; the UI reports returned/rejected requests without assuming ability success.

Validation: compiled the complete generated script, replayed the actual uploaded string-keyed BattleState shape, and mocked all three conditions, multiple independent card rules, exact payload, event-driven HP updates, strict thresholds, dead/suppressed/unavailable casters, lane isolation, ended/stale snapshots, re-execution history, native-use suppression, request spacing, uncertain errors and profile/pending/stop guards. Config tests verify multiple card rules plus enabled/lane settings round-trip and legacy OFF defaults. Existing Story, Skill Tree, Higher or Lower, Monitor and webhook checks pass. Live Roblox UI and actual GuestActive server acceptance remain untested.
