# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [4.6.0] - 2026-09-09

Runs on Qbox. Every framework branch in this resource was replaced by the
msk_core bridge, which removed roughly a hundred lines without changing what the
script does.

### Requires

- **msk_core 4.0.0 or newer.** This release calls `MSK.GetPlayer`,
  `MSK.GetPlayers`, `MSK.RegisterItem` and `MSK.Bridge.Framework.Type` in their
  4.0.0 form. On msk_core 3.x the player object arrives without its methods and
  the item removal fails. Update msk_core along with this script.

### Added

- **Qbox support.** Qbox uses the same `player_vehicles` layout as QBCore,
  verified against `qbx_vehicles/vehicles.sql`.
- `GetPlayerIdentifier(Player)` as a helper of its own. The identifier used to be
  read inline in three places, each with its own ESX and QBCore branch.

### Changed

- **Framework detection is gone from this resource.** It sat at the top of
  `client/main.lua`, `server/main.lua` and `server/hotwire.lua`, once per file,
  and knew only ESX and QBCore. msk_core has already detected the framework when
  these files load.
- **`Config.Framework` is no longer read anywhere.** The line stays in
  `config.lua` so an existing config does not break, but changing it has no
  effect. Pin the framework in msk_core's `config.lua` instead.
- Usable items are registered through `MSK.RegisterItem`, which covers ESX,
  QBCore and Qbox in one call, instead of `ESX.RegisterUsableItem` and
  `QBCore.Functions.CreateUseableItem` side by side.
- The police alert walks `MSK.GetPlayers()`, one list with the same fields on
  every framework, instead of `ESX.GetExtendedPlayers` and
  `QBCore.Functions.GetQBPlayers`.
- `GetPlayerFromId`, `GetPlayerFromIdentifier` and `GetPlayerJob` keep their
  names, because the rest of the resource calls them, but they are one line each
  now.

### Fixed

- Removing the lockpick item no longer runs against a `nil` player when the
  lookup fails.

### Changed files

```text
fxmanifest.lua
config.lua
client/main.lua
server/main.lua
server/hotwire.lua
```

## [4.5.0] - 2026-07-19

### Security

- Key handout while lockpicking is now authorized on the server. The open `addTempKey` event was removed. Keys are only granted after a serverside distance and probability check. Previously any client could grant itself a key for any vehicle.
- The search-for-key roll now happens on the server instead of the client (no more clientside `math.random`).
- Owner, police and live-location alerts now run fully serverside through the new `triggerAlarm` event. Coordinates, owner and plate are resolved on the server from the vehicle and can no longer be manipulated. The old open events `ownerAlert`, `policeAlert` and `liveCoords` were removed.
- The owner identifier is no longer sent to the lockpicking client. `getAlarmStage` now only returns the alarm stage to the client.
- The alarm stage is validated against the config before it is written to the database.
- Distance and cooldown checks were added to the serverside events to prevent spam.

### Added

- New serverside hook `msk_enginetoggle:engineToggled` with the parameters `src`, `netId`, `state`, so other resources can react to engine toggles on the server. The incoming client trigger is validated with a distance check first.
- Automatic GitHub release workflow that creates a release with a ZIP and changelog whenever the version in `fxmanifest.lua` is bumped.

### Changed

- The heli and plane thread no longer writes a replicated statebag inside the loop and uses a read-only check instead. This lowers performance and network load.
- The database query on vehicle enter now only runs for vehicles flagged as stolen instead of on every enter by every player.
- `assert` in the exported functions was replaced with graceful returns so other resources no longer crash on invalid vehicles.
- `Config.Debug` now defaults to `false`.
- Minor cleanup: simplified steering angle logic, explicit returns in the whitelist and blacklist checks.

### Removed

- Dead, non-functional serverside trigger of the old `toggledEngine` event. It was replaced by the validated `engineToggled` hook.
- Open, spoofable events `addTempKey`, `ownerAlert`, `policeAlert` and `liveCoords`.

### Changed files

- `config.lua`
- `client/main.lua`
- `client/hotwire.lua`
- `client/steeringwheel.lua`
- `client/utils.lua`
- `server/main.lua`
- `server/hotwire.lua`
- `fxmanifest.lua`
- `CHANGELOG.md` (new)
- `.github/workflows/release.yml` (new)
- `.gitattributes`

---

Older versions are documented in the [GitHub Releases](https://github.com/MSK-Scripts/msk_enginetoggle/releases).
