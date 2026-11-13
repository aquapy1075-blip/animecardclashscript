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

## Guess Minigame

The new Guess Minigame tab uses an ON/OFF toggle, live status, streak and loaded stat-entry count. Restart after game ends defaults OFF and is stored in Config. Stand near the native Guess Minigame activity where the server requires it; the script does not teleport or bypass proximity checks. Avoid manually submitting guesses while Auto Guess Minigame is running.

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

Turning OFF stops future guesses and uses the native quit action for its active session after any pending request returns. Start is blocked until cleanup completes, preventing an old worker from quitting a new session. Reloading is blocked while a Guess Minigame worker is still active; turn it off and wait for cleanup first.

Tests passed for variant-aware totals, higher/lower/higher rounds, equal/unknown/mismatched stats, server round advancement, request spacing, completed sessions, server-ended events, and Stop/restart cleanup. Story and skill regression tests passed. Live-game requests and actual pool contents still require verification in Roblox. COPY CAPTURE includes HigherLowerGuess, HigherLowerResponse and HigherLowerEnded records.


## Unified mode toggles and persisted execution state

Story, Auto Skill Tree and Guess Minigame each use one ON/OFF toggle. Separate Skill Tree START/STOP buttons are removed.

SAVE synchronizes actual current worker states into StoryRunning, SkillRunning and HLRunning, then writes those booleans with settings. LOAD restores both ON and OFF and applies them to actual workers. SET AUTO LOAD causes the next execution to restore selections/settings, build the UI/controllers, then start each mode saved ON. This includes selected skill purchases when Auto Skill Tree was saved ON. Older profiles missing a toggle key default that mode OFF.

To persist a mode ON: configure it, turn it ON, SAVE, then SET AUTO LOAD for that profile. To change the saved state to OFF, turn it OFF and SAVE again. Finishing a queue turns its live toggle OFF but does not silently overwrite the saved profile.

Manual LOAD first reads/validates the profile, stops existing mode scheduling, and waits for pending requests / Guess Minigame cleanup. If the new profile enables Story, it also waits for a currently tracked Story fight to end. After 30 seconds still waiting, the load aborts without applying new selections; load again after outstanding work ends. Tracked results are still received while Story scheduling is OFF. Parallel profile loads and edits during profile transitions are blocked.

Mocks verified all three ON/OFF states, actual-state saves even before the repaint loop runs, loading an OFF profile while workers are active, restoring an ON profile, deferred startup auto-load, and legacy OFF defaults. Story, skills and Guess Minigame regression checks still pass. Live Roblox/executor file behavior remains untested.


## Monitor tab: raid currency and server Domain

Raid currency now contains only Bone Tokens, from ProfileSync.currency.boneTokens or SkeletonRaid Result.data.total. Balance delta, rate, update age, refresh and reset controls have been removed. Other currency still shows War Coins separately. Unknown balances remain Waiting for sync rather than an invented zero.

Server Domain shows its current name, countdown, luck boost and opener using ReplicatedStorage DomainId / DomainEndsAt / DomainBy, live DomainConfig and the server clock. Currency/result listeners continue while the tab is hidden.


## Webhook

Monitor → Webhook contains a Discord webhook URL field, Domain alerts toggle, a searchable multi-select Notify for Domains dropdown and SEND TEST. Removed: Remove webhook URL, delivery status/counters, Rarest random Domain and the separate Clash toggle.

The URL field shows the current value. Replacing it and leaving the field replaces the endpoint; clearing it (including whitespace-only input) and leaving the field removes the saved endpoint. Invalid URLs keep the existing endpoint and show a short validation notification. SAVE persists the current URL in the local Config profile; it is not uploaded in capture logs.

The dropdown displays each Domain's name and normalized random weight percentage. Live DomainConfig.Order/Data is authoritative; before config is available it uses the uploaded place's fallback list:
- Horizon of the Captivating Beach: 58.4%.
- Coffin of Death: 30%.
- Unyielding Love: 10%.
- Judge Courtroom: 1%.
- Shrine of Sorrow: 0.5%.
- Infinite Void: 0.1%.
- Domain Clash: 0% random, special event.

Only selected Domains trigger automatic notifications. The old rarest-only behavior is removed. The watcher runs independently of visible tabs/window rendering and retains per-server occurrence deduplication across re-execution and duration extensions. Changing the URL permits the current selected occurrence to notify the new destination. Requests use the executor HTTP API, keep a five-second gap and retry HTTP 429 at most twice. Turning alerts OFF, unselecting the current Domain or unloading cancels queued automatic retries. Already-sent requests cannot be recalled.

WeatherWebhookDomains saves the selected internal IDs in Config, including an explicitly empty selection. Existing profiles migrate to Infinite Void plus Domain Clash unless the old Clash toggle was OFF. URL and global toggle retain their existing profile keys. Test delivery is manually initiated and does not depend on Domain selection. Profile files contain the URL in plain text; remove it before sharing a profile.

Validation uses mocked HTTP only: common and rare selected Domain alerts, unselected suppression, fallback/live percentages, zero-random special events, selection persistence and legacy migration, URL replacement/clearing, restart deduplication, retry/cancellation and removed UI controls. Real Discord delivery and live Roblox rendering remain untested.


## Combat Helper: per-card conditional GuestActive

The Combat Helper tab discovers ability-bearing cards from BattleState.guestActives. During active battles the card picker lists ability cards from the selected lane(s); Both lanes combines their ability cards. Before a snapshot is available, it offers previously discovered/saved cards and SCP3008. Each discovered card starts with its rule OFF; this avoids spending abilities before a condition is configured. First receive a combat snapshot to populate the deck's ability list.

Choose Battles 1, 2 or Both lanes and turn Auto active ON. Pick a Card, turn Use this card ON, and choose Use when. Both lanes applies the same per-card rules to both battles; HP, rounds, battle IDs and ability-use history remain separate. Choose one condition:
- Combat start: requires an observed fresh/round-1 battle and fires only while round is at most 1. Enabling it midway does not count as combat start.
- Low HP: use the 1–99% mouse/touch slider. Watch card offers Any living card (stored as slot 0), including cards in hand, or Slot 1–5 for a specific deck slot. HP must be strictly below the threshold; dead or unknown-HP cards do not trigger.
- Round: use at the chosen round or later, once the ability becomes available. The round input is clamped to 1–999.

Example: pick SCP3008 → enable this card rule → Low HP → target slot 2 → 50%. Then enable conditional actives. The SCP3008 No Exit implementation heals all living allies to full; it also retains its native location/status effects. Other ability cards can independently use Combat start or Round rules. The game’s own automatic active-use feature must be turned OFF manually so it does not consume an ability ahead of these rules.

The controller reads full BattleState snapshots and updates HP/rounds using matching Damage, Heal, Stat, Revive, Death and RoundStart events. Conditions use server HP rather than GUI visibility. Both lanes scans each selected battle independently. Ready requests alternate lane priority, remain sequential and at least one second apart, so one lane cannot consume the other's per-battle use. Ending one lane does not stop the other. Each request is exactly BattleAction:InvokeServer("GuestActive", {cardId=..., battleId=currentBattleId, lane=selectedLane}), matching the user's supplied payload. An available ability and living, unsuppressed caster are required. Ended/superseded IDs and mismatched lane events are ignored; stale battle data waits for a fresh update.

This version attempts each card at most once per battle, including abilities that might have a native cooldown. Attempts are recorded before yielding and retained across re-execution, with bounded history. Native/manual GuestActive events also suppress duplicate requests. Rejected/uncertain calls are logged without automatic retries. Requests are at least one second apart and do not overlap Story admission; Story waits for an outstanding active request before another admission. Disabling the global toggle stops future requests; an already-sent InvokeServer cannot be cancelled.

Config SAVE/LOAD/Auto Load preserve the global toggle, selected lane/card and independent per-card rule settings. Legacy profiles default conditional actives OFF. Profile loading waits for outstanding active requests. UNLOAD disconnects the listeners and stops the watcher. COPY CAPTURE includes ActiveRuleRequest and ActiveRuleResponse; the UI reports returned/rejected requests without assuming ability success.

Validation: compiled the complete generated script, replayed the actual uploaded string-keyed BattleState shape, and mocked all three conditions, multiple independent card rules, exact payload, event-driven HP updates, strict thresholds, dead/suppressed/unavailable casters, lane isolation, ended/stale snapshots, re-execution history, native-use suppression, request spacing, uncertain errors and profile/pending/stop guards. Config tests verify multiple card rules plus enabled/lane settings round-trip and legacy OFF defaults. Existing Story, Skill Tree, Guess Minigame, Monitor and webhook checks pass. Live Roblox UI and actual GuestActive server acceptance remain untested.

## Simpler Combat Helper controls and Both lanes

The Combat Helper tab now shows a compact setup: Auto active, Battles, Card, Use this card and Use when. Both lanes is the third Battles option and is saved/restored by Config; existing numeric lane selections and legacy defaults remain compatible.

Only condition-specific fields are visible:
- Low HP shows Watch card and the HP slider.
- Round shows only its round input.
- Combat start needs no extra fields.

Rule status, Ability card list and Request limit rows are removed. Last request and per-lane HP/round values live under Battle details → SHOW, collapsed by default. Native-auto guidance and discovery information are attached as tooltips rather than permanent status rows. Card changes and profile loads refresh visible fields while retaining each condition's saved values. The HP slider cancels dragging when its mode is hidden.

Mock checks cover the third dropdown option, independent same-card triggers in two simultaneous battles, per-lane HP and completion isolation, union card picker, surviving-lane operation, Config round-trip with Both lanes, and numeric lane compatibility. A separate mocked UI check exercises all three condition layouts, card/profile mode refresh, friendly slot mapping, collapsed/expanded details, selected-lane detail visibility and removal of redundant rows. Full generated-script syntax, existing active rules, Config and Story regression checks pass. Live Roblox visuals/input remain untested.

## Switching boss after stopping Story

The latest user capture shows FirstDemon/Cosmic admitted as battle 11042356355-173920058, then Story scheduling stopped while that native fight continued. SonProdigy/Cosmic requests were rejected explicitly with "you are already in a story battle". This is an admission refusal, not a missing successful battle ID.

A verified in-flight Story tracker now survives OFF/ON and script re-execution. Starting a different selection waits for the matching prior BattleEnd before sending the first new StartEncounter. An unrelated lane/battle result does not release the wait, and the old result never advances the new selection. OFF cancels this wait; after 15 minutes without a matching end, scheduling stops. Stop still leaves native combat running.

If the server rejects a start, the UI now shows its reason. An already-running Story battle that was never tracked by this controller requires waiting for native completion and turning Auto Story ON again; the script does not guess its identity or cancel it. No server restrictions are bypassed.

Checks replay the actual uploaded refusal and mock stop/switch waiting, unrelated/wrong-lane events, old-loss isolation, wait cancellation and verified tracker handoff across re-execution. Story, Config, active rules and compact-UI regression checks pass. Live Roblox verification remains outstanding.

## Current names and theme-aware text

The Higher or Lower tab is now Guess Minigame and its How it chooses section has been removed. The Active Rules tab is now Combat Helper. Gameplay remotes, per-card rules, Both lanes behavior and existing Config keys remain compatible.

Text gradients now derive their colors from the selected theme's accent, text and mint tokens. All six themes update their palettes instead of sharing one fixed dark-theme gradient. Light uses darker readable text on light surfaces; the fixed dark Story header retains a brighter variant for contrast.

Full generated-script syntax and mocked checks passed for compact Monitor, URL replace/clear, multi-select Domain odds and selections, Config migration/empty selections, actual six-theme text repaint, renamed tabs and removed sections. Existing Story switching, conditional actives, Guess Minigame, Skill Tree and Monitor checks passed. No live Roblox visual verification or real HTTP delivery was performed.

## Multiple Combat start abilities: resolving-conflict fix

The latest uploaded capture contains explicit GuestActive refusals for StrongestCurse after SkeletonBoss: pcall succeeded, admission was false, and the message was "the ability is already resolving". The prior controller consumed its local attempt mark on this refusal and never retried.

Combat Helper now arms every enabled Combat start rule when a selected lane's round-1 snapshot is received, before choosing the first ability. These pending start intents survive a round change for at most ten seconds while the same battle remains active. This also covers a round advancing before the worker scans the second lane. Enabling a new Combat start rule after round 1 does not arm it.

Only the exact confirmed transient refusal above releases an attempt mark and schedules bounded backoff (0.5, 1 and 2 seconds, still respecting the existing global one-second request gap), at most three retries. Other refusals, transport errors and unknown replies retain the no-replay policy. Server used/queued states and GuestActive events confirm consumption and prevent releasing an already-consumed mark. Ending/replacing a battle, disabling auto or stale/unavailable/dead-caster data prevents later requests. Both lanes keep their own pending intents and use history.

Mock checks use the actual uploaded refusal and cover two start abilities across a round change, both-lane snapshot latching, retry limits, accepted/queued/native-use suppression, OFF/end cancellation and existing Story/Config behavior. Live Roblox server integration remains untested. A short fight may still end before another active can be accepted; the script does not send against an ended battle.

## Domain webhook mentions

Automatic Domain alerts now include content @everyone and explicitly allow the everyone mention in the Discord payload, as requested. Manual connection tests remain labelled tests. Existing URL, Domain selection, occurrence deduplication and Config behavior are preserved. Webhook payload validation used mocked HTTP; no real Discord request was sent.

## Autoexec, automatic rejoin and branding

Settings now has one Autoexec toggle, OFF until enabled. It saves immediately to OriginStory/autoexec.json independently of Config profiles, so loading an older gameplay profile does not override the startup switch. Auto Load in Config still controls which saved gameplay modes restart when the script executes.

When Autoexec is ON, OnTeleport Started/InProgress queues the stable branch loader using queue_on_teleport, queueonteleport or syn.queue_on_teleport when available. It queues once per outgoing script session. If the executor exposes an existing writable autoexec folder, the switch also installs autoexec/AnimeCardOnline-aquacodex.lua for future injections. OFF removes only that owned file where deletion is supported; persisted OFF makes previously queued copies no-ops. It does not create an unrecognized executor autoexec directory or modify other startup files. The loader is scoped to this game's universe (or place if universe ID is unavailable), waits for game load and guards duplicate starts in the same server.

Executors differ: queue support enables reload on teleports; an autoexec folder enables automatic execution after a fresh client injection. Neither injects an executor into a new client. Missing capabilities produce a short notification; without file APIs the setting cannot persist across sessions.

Auto rejoin is always enabled while the script is alive, with no UI toggle. It watches GuiService's native error message and visible RobloxPromptGui/promptOverlay/ErrorPrompt, waits two seconds and calls client TeleportService:Teleport for the current place. Retry delays increase to 60 seconds, with at most six attempts per continuous disconnect episode and no overlapping in-flight attempt. TeleportInitFailed releases the in-flight attempt, and an attempt with no completion times out after 20 seconds. No disconnect means no teleport. UNLOAD stops the watcher and disconnects listeners. Rejoin can only work while Roblox/executor code is still running; it cannot fix an unavailable service or restart a terminated client.

The header now reads Anime Card Online and made by aquacodex. The subtitle stays fixed across tab switches. The AO header and mobile toggle monograms are replaced with the current place's game icon, resolved through MarketplaceService GetProductInfo.IconImageAssetId. Icon updates follow the existing UI refresh lifecycle and skip unchanged image writes.

Validation: full generated-script syntax, mocked default rejoin/backoff/cap, native prompt detection, init failures, ON/OFF persistence, owned loader install/removal, one queued loader, later-OFF and cross-game guards, duplicate boot prevention, icon lookup and unload. Existing Story, boss switching, Config, Combat Helper and Monitor UI checks pass. Actual executor startup folders/queue APIs, live disconnect recovery and Roblox icon rendering have not been verified in-game.

## AFK settings and startup load guard

The standalone entry now begins with repeat task.wait() until game:IsLoaded() before any modules/controllers initialize. It also waits for Players.LocalPlayer before reading client state. Existing queued autoexec loaders retain their game-load guard.

Settings → AFK adds:
- Anti-AFK, default ON: listens to LocalPlayer.Idled and invokes VirtualUser CaptureController/ClickButton2 only when that native idle signal fires, limited to once per 60 seconds. OFF stops future synthetic input. No game remotes, anti-cheat hooks, signal disabling or stealth mechanism are used. An executor may reject VirtualUser input; no detection-resistance or guaranteed idle protection is claimed.
- Save CPU (15 FPS), default OFF: uses setfpscap when available and reduces this script's UI refresh to once a second. It restores the previous cap from getfpscap on OFF/UNLOAD, or 60 FPS when a readable cap is unavailable. Without an FPS API only the reduced UI refresh is applied. Gameplay automation workers retain their own scheduling.
- White Screen, default OFF: places a white overlay above normal game UI and requests Set3dRenderingEnabled(false). The script UI remains above the overlay, and Show game disables White Screen without needing the main window. OFF and UNLOAD restore rendering to its prior readable value (otherwise enabled) and remove/hide the owned overlay. Rendering API denial leaves the visual overlay available and reports the limit. White Screen alone does not claim to stop all CPU/game logic.

These three settings persist through Config SAVE/LOAD/SET AUTO LOAD. Legacy profiles use Anti-AFK ON, Save CPU OFF and White Screen OFF. Re-execution/UNLOAD cleans up the old runtime, restores graphics settings and disconnects the idle listener.

Tests: real entry guard in a coroutine, throttled Idled-only input, independent FPS/white controls, prior FPS and prior-enabled/disabled rendering restoration, accessible Show game button, unload, unsupported APIs and profile round-trips/legacy defaults. Generated Lua syntax and existing Story switching, autoexec/rejoin, Combat Helper and compact Monitor checks pass. Actual executor permission, idle prevention, visual rendering and resource savings require in-game verification.

## Dungeon: smart progression

Implemented from the updated Place_139541882461209.rbxlx supplied inside aco.zip. GateConfig.Order is E → D → C → B → A → S → Red. Every regular gate has 100 floors; Red is endless. The live server's returned best state and GateConfig.isUnlocked determine eligibility, never guessed UI visibility. E/D/C are initially open in the supplied config, but Smart progression starts at E and proceeds sequentially.

Dungeon → Auto Dungeon enters E, enables native dungeon autoplay to handle floors/hunters/bosses, and advances after a matched GateEvent dungeon phase cleared. A matched heart/down/fallen event counts as a loss immediately; it leaves that run and farms the preceding gate. That fallback stays pinned even after a win; another loss steps down again. A loss in E stops after leaving. Turning Auto Dungeon OFF and ON begins a new E-first progression. At the current highest unlocked gate, a clear repeats that gate unless the refreshed unlock data permits advancement. Closed scheduled gates wait for GateConfig.window and server time rather than skipping ahead. Red continues until a loss/exit or timeout.

The worker uses GateAction state, auto, enter, autoplay and leave, and matches GateEvent run.id/gate. Script-managed progression disables native post-result auto-hop so it does not race gate selection. An existing unowned dungeon must be left manually before starting this worker. Missing admission IDs, unknown endings, server refusals, or two hours without a matching result stop with diagnostics. No downBuy, reset, revive or other paid action is sent. The game's own location, admission and gate-window checks remain authoritative.

OFF stops future scheduling and disables native autoplay after an outstanding request returns; it leaves the current run in place. Config SAVE/LOAD/SET AUTO LOAD preserve DungeonRunning. Profile switches wait for old workers/requests; re-execution is blocked until pending Dungeon/System work finishes. COPY CAPTURE includes DungeonRequest, DungeonResponse, DungeonResult and stop diagnostics.

## Auto System priorities

Dungeon → Auto System can run independently of Auto Dungeon. Choose Priority 1–5 from LUK, STR, VIT, AGI, SEN; choosing an already-used stat swaps positions so the order stays unique. Default: LUK → STR → VIT → AGI → SEN.

The allocator reads confirmed points.earned and current stat values, fills Priority 1 to its currently unlocked GateConfig.statLimit, then allocates remaining points to the next priority. It rechecks from the top on the next pass, including when clearing a gate raises limits. The supplied config starts at 20% of each stat's maximum and raises that to 40/60/80/100% on C/B/A/S clears.

Uses the native GateAction spend payload with str/vit/agi/sen/luk amounts. After an accepted spend it refreshes state and verifies the stat increases before allowing another allocation. Missing data waits; refusals, errors or unconfirmed spending stop Auto System without blind retry. Only earned System points are allocated; no reset, quest claim, coin purchase or Robux transaction is automated. SystemRunning and SystemPriority persist in Config. Old profiles default both new automation toggles OFF.

Dungeon and System share a serialized GateAction request manager with at least a one-second gap, including slow requests. UI remains compact: Auto Dungeon, current status/gate/floor, Auto System, five priorities and System status.

Validation: full Lua syntax; mocked E-first progression, live unlocks, matched wins/losses, pinned fallback, E-loss stop, unrelated run filtering, early-result race, scheduled-gate waiting, OFF cleanup, admission refusal and existing-run guard. System checks cover strict/partial allocation, current caps, unique reorder, independent operation, confirmed server balances, no blind repeat, Config round-trips/legacy defaults and concurrent worker serialization. Existing Story, AFK, Autoexec/rejoin, Combat Helper, minigame and compact UI checks pass. The source protocol is verified against native client scripts, but live GateAction/GateEvent acceptance and actual dungeon gameplay remain untested; COPY CAPTURE is available for any integration mismatch.

## GateAction Slow down and repeated-gate option

The user's live screenshot reports Slow down for both Dungeon and System. The native GateController also treats this exact explicit refusal as transient. The script now prefers GateUI.api.call when initialized, sharing the native client's request coordination. Its own workers remain serialized, with a 1.5-second minimum interval. Exact false / Slow down responses retry at most three times after 2/4/8-second backoff. Transport errors, accepted side effects and other refusal messages are not replayed. Exhaustion produces a readable Server busy message, without a Lua source-line prefix.

Dungeon waits on matched events and polls state only about every eight seconds while fighting; Auto System checks about every ten seconds. This reduces contention with native UI state requests. OFF cancels queued retries. Native API unavailability falls back to the verified GateAction remote. The server's actual quota is unknown; these are conservative client timings, not a bypass or a claim of guaranteed admission.

Dungeon → On loss now offers Previous gate (existing default) or Retry same gate. Retry same gate leaves/re-enters the same gate after a verified loss, including E, using the game's saved floor/hearts. A confirmed clear then continues normal progression. Previous gate retains pinned fallback farming and stops after an E loss. DungeonLossMode persists in Config; old profiles retain Previous gate. No paid revive/reset is automated.

Native dungeon AUTO handles fighting/progression inside the selected gate. Script Smart progression manages gate choice and loss policy; the user need not manually toggle native AUTO while the script manages a run.

For farming decisions, the supplied update notes state every tenth gate floor pays Gate Coins every run, while System milestone points and regular-gate milestone Essence/Cores are first-clear rewards. Gate clears also give a 24-hour luck buff. Red has a separate endless reward table beyond floor 100. Repeated regular gates are primarily a Gate Coin goal, not an assumption of unlimited first-clear rewards.

Checks passed for transient recovery/backoff limits, OFF cancellation, native shared API selection, one confirmed System allocation after refused attempts, slower serialized workers, both loss policies, Config persistence and existing Story behavior. Live server acceptance remains to be verified; no real GateAction or paid action was sent during testing.
