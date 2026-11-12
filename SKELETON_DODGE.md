# Skeleton Raid movement assist (prototype)

This is an experimental **auto-dodge assist**, not a complete auto-raid loop. Enter the raid and choose cards manually. Full start/deck-selection commands have not been captured. The inbound capture does not reveal their argument schema, so no guessed remote commands are sent.

## Evidence from uploaded log

99 records, zero dropped records and zero capture errors. One complete Judgment win is recorded:
- Phase Prepare → Intro → Pick → Take.
- Attack / Turn through rounds 1–5, with FakeDeath after round 4.
- Sleep → Victory.
- Result with data.won=true, diff Judgment, first=true, tokens=150.
- Closed with reason Victory.

The next Final run ends in the uploaded capture at Pick. Its outcome is not present. The Judgment start-to-Victory interval is approximately 218.5 seconds, so this does not establish a faster clear than the configured 180-second AFK route.

## How the assist works

Loads the native Shared.SkeletonRaid Config and DodgeBox module. Replaces the module's movement method with a wrapper that chooses the native input.stick and input.btnJump values, then calls the original movement method. Existing DodgeBox instances share the same module methods. The native update time is captured to evaluate the hazard timeline in the same clock domain.

A short lookahead scores white/blue/orange bones, rotating arms and beam segments; gravity/jump prediction follows the native Box settings. Only controls are changed. The script does not modify actual heart position directly, invulnerability, HP, hit counters, timers or rewards. It does not hook namecall or send remote requests.

It is a heuristic: future unspawned hazards, changing boxes and phone-specific transformations are not fully predicted. Damage and failed runs remain possible, particularly in Final. Keep the raid screen active and avoid simultaneous manual movement while testing.

## Use

Run skeleton_auto_dodge.lua before or during the native raid minigame. Start and deck selection remain manual.

Stop and restore native movement/update methods:
```lua
getgenv().OriginSkeletonDodge.stop()
```

Inspect:
```lua
print(getgenv().OriginSkeletonDodge.status())
```

Re-running stops the old assist before installing the new wrapper. Restoration only replaces methods still owned by this assist.

## Validation

Script syntax compilation and synthetic tests passed for white/blue/orange danger rules, horizontal beam escape, gravity jump, keeping real heart state unchanged during planning, using native update time, forwarding native calls and restoring methods/input on Stop. These are not live-game survival or performance tests. No promise of perfect dodging or faster-than-AFK clears is made.
