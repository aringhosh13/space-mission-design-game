# Hands-on First Light missions

Start the First Light campaign with the package launcher or `-- --campaign`. The existing landings,
driving, route planner, storms, collision and twelve-objective story remain. Field investigation now uses
short interactive tools instead of immediately completing from one keypress.

## Field actions

- **E / Scan:** approach within the existing interaction distance. Use Left/Right or the slider to tune
  the displayed signal peak, then hold Space or the operation button to acquire a stable lock. This is
  instrument-alignment gameplay, not a NASA spectrum. It does not reveal the hidden signal outcome.
- **Q / Sample:** first scan the site and carry the drill. Adjust feed with Left/Right or the slider;
  hold Space/the button while watching the feed and heat indicators. Release to cool. Too much feed
  stops progress; overheating triggers automatic cooling. Retrying loses no science or extra energy.
- **A / Assist:** available within scanner and drill tools. It completes the same operation with the
  same engine costs and evidence; it does not add science or improve findings.
- **B / Station:** review sunlight, deployment cost, remaining battery and an estimated straight-line
  return drive plus a suggested reserve. Shadow or insufficient deployment power disables committing.
  A tight return estimate is advisory because recharging and detours are not included. Return to driving
  to choose another site; Enter/the button commits the current site.
- **Results:** each completed tool explains the actual finding, the problem it addresses and a useful
  next action. Enter/Continue returns to driving. Escape cancels or closes a tool. Cancelling before
  completion spends no action energy and awards nothing. Audio settings also work while a tool is open.

Driving and the surface clock pause during tool operation so this remains forgiving. The simulation still
revalidates phase, site and resources and applies its existing costs/rewards once. Closing a tool or
checkpoint restoration cannot create a late action. A ruled-out resource signal remains useful science.
On Mars, physical core science still requires transport back to the Moon base; the control game does not
award an Earth sample delivery. Programmatic `surface.act()` remains the engine integration API; human
keyboard and HUD requests go through the interactive controls.

## Scientific framing

NASA's [Perseverance abrasion explanation](https://science.nasa.gov/blog/why-and-how-perseverance-abrades-rocks/)
describes exposing fresh rock for instrument study before selecting a core. That motivates the
measure-then-sample sequence. Our signal tuning, feed, heat, timing and energy numbers are fictional,
not actual spacecraft operating instructions. The local deployment budget uses the game's distance-based
energy rules; it is separate from the measured-DEM regional planner and is not an operational safety check.
LOLA/MOLA data, game-world simplifications and the historical Artemis I reference retain their credits.

## Audio

An original 48-second ambient score provides soft harmonic pads and sparse bell notes. Synthesised
instrument tones, checkpoint cues, impact feedback and vehicle loops support player actions. A Mars storm
adds a wind layer; no atmospheric-wind layer plays on the Moon. NASA's
[Sounds of Mars](https://science.nasa.gov/mission/mars-2020-perseverance/sounds-of-mars/) documents real
rover recordings, but none of those recordings is copied here. Vehicle sounds are stylised operator
feedback; music is a soundtrack, not a claim about sound propagation through vacuum.

Open **Audio [F8]** for separate music/effects levels and mute. The game pauses while settings are open,
including an active instrument or cutscene, and restores its previous pause state on close. Settings
persist locally. All instructions and progress remain visual so sound is optional. See
[audio provenance and regeneration](audio/README.md).

## Checks

`tests/integration/interactive_checks.gd` exercises manual input, assist, premature/duplicate commits,
cancel/recovery, unchanged costs/rewards, shadow rejection, audio pause/mute and Moon/Mars sound contexts.
The full campaign driver now operates the tools with player-equivalent inputs and checks continued music
playback. It still drives the full route and manually flies every landing without resource/position edits.
Existing scene, cinematic and solid-prop checks remain separate. These automated checks do not replace a
human assessment of pacing, difficulty or listening comfort.

Verified on official Godot 4.7.2 for Windows: 29 interactive/audio checks pass, including held-button result
handling; the complete manual-landing campaign passes 50 checks on RTX 4050 OpenGL, including all five new
field operations and continued soundtrack playback; 115 scene checks and the cinematic flow pass without
runtime errors. The rendered instrument, result, deployment and audio panels were captured and inspected.
