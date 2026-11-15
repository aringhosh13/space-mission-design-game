# Science behind First Light

Press **F2** or click **Science** at any time. The planning screen has a larger **NASA Science & Sources**
button, and completed instrument operations have **Why This Matters / NASA Science**. The reference opens
with the Moon or Mars topic appropriate to the expedition; an active Mars storm selects the dust topic.
Every tab is available immediately. F2/Escape returns to the same activity.

The five tabs cover lunar polar ice, Jezero delta rocks, Mars dust, the elevation datasets and project
credits/scope. The three photos/maps are bundled: no network connection or API key is required to read
them. **Open NASA Source** explicitly opens the published article in the player's browser. The image is
contained within its panel rather than cropped; long text scrolls independently, while the source button
remains visible. Credits remain next to each image.

## Observations → decisions → limitations

- **Moon:** NASA's M³ instrument aboard ISRO's Chandrayaan-1 detected patchy polar surface ice. The game
  asks the player to distinguish a clue from tested evidence while preserving return power. The reference
  image does not determine game signal positions and is not a mineable-resource inventory.
- **Jezero:** Perseverance's annotated SuperCam RMI delta-scarp mosaic illustrates sedimentary structures.
  Players investigate layered rocks and collect a core in the fictional campaign. No discovery of life or
  completed real Mars sample return is claimed. This photo does not supply the Mars heightmap.
- **Dust:** Curiosity's 2018 before/during-dust comparison illustrates changed surface illumination.
  Opportunity depended on solar energy; Curiosity uses a radioisotope system. The player manages a
  fictional rover's charging, reserve and shelter. Storm timing, strength and recovery services are game rules.
- **Elevation:** the existing LOLA LDEM_16 V3.1 and MOLA MEGT90N000EB V2.0 sources now have a player-facing
  catalogue. Raw physical elevations/distance feed the regional study model. Compressed game terrain and
  fictional fine features are not suitable for operational route planning. Full processing is documented
  under `data/terrain/README.md`, `MOLA.md` and `ROUTE_PLANNING.md`.

This is an educational project addressing the challenge of understanding mission trade-offs. A feasible
route meets the stated simplified model; it is not NASA-approved or flight validated. Rocks, wheel slip,
actual illumination, thermal survival and communications still need separate checks.

## Project identity and attribution

The horizon/return-traverse badge is original Blue Horizon vector artwork written with AI assistance.
It appears in mission planning, the archive header, on the rover front plate and on a spacecraft wing.
It is decorative and adds no collision or simulation logic. No NASA meatball, worm, seal or mission logo
was added. The credit page identifies the independent project and AI-assisted development accurately;
it does not imply NASA sponsorship or endorsement.

Photo credits and exact download provenance: [NASA media manifest](assets/nasa/README.md) and
[`manifest.json`](assets/nasa/manifest.json). Original identity provenance: [badge notes](assets/identity/README.md).
The game presents these science images as observations, not as generative artwork or in-game discoveries.

## Verification

`tests/integration/science_archive_checks.gd` exercises real F2/F1/F8/Escape events, offline image loading,
all five pages, non-overlapping access controls, badge bounds, unchanged mission/design state, preservation
of an existing pause and focus/activity, and frozen cinematics/instruments while reading. It runs headless
or with the actual renderer and optional screenshot output. Instrument regressions and the full driven
campaign route remain separate checks. Automated checks do not replace a human playtest.

```sh
godot --headless --path . --fixed-fps 60 --script res://tests/integration/science_archive_checks.gd
```
