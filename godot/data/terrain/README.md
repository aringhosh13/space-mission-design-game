# NASA lunar elevation used in Blue Horizon

These are actual data-derived elevation resources, not AI-generated terrain measurements.
Codex wrote the import/rendering code under the team's direction.

## Source

- Mission/instrument: NASA Lunar Reconnaissance Orbiter / Lunar Orbiter Laser Altimeter (LOLA).
- Producer: LOLA Science Team, NASA Goddard Space Flight Center; PDS Geosciences Node archive.
- Product: **LDEM_16**, product version **V3.1**, dataset **LRO-L-LOLA-4-GDR-V1.0**.
- Product creation date: 2019-03-15. Source observations span 2009-07-13 to 2016-11-29.
- Archive: https://pds-geosciences.wustl.edu/missions/lro/lola.htm
- Exact binary: https://pds-geosciences.wustl.edu/lro/lro-l-lola-3-rdr-v1/lrolol_1xxx/data/lola_gdr/cylindrical/img/ldem_16.img
- Exact label: https://pds-geosciences.wustl.edu/lro/lro-l-lola-3-rdr-v1/lrolol_1xxx/data/lola_gdr/cylindrical/img/ldem_16.lbl
- Retrieved 2026-11-14. The original label and SHA-256 of the 33,177,600-byte IMG are preserved here.

The original grid is 5760 × 2880, 16 pixels/degree, simple cylindrical, east-positive longitude 0–360,
rows north to south, pixel registered. Samples are signed 16-bit little-endian integers.
**Elevation = DN × 0.5 metres** relative to a 1737.4 km reference sphere. Do not add the label's OFFSET
to elevation; the offset is only needed to obtain planetary radius. Equatorial spacing is approximately
1895.21 m; longitudinal physical spacing decreases toward the poles. The label notes possible artifacts
at 45-degree latitude-band joins and interpolation where coverage is incomplete.

## Reproduction

Download the exact IMG and matching LBL into the same folder, then run:

```sh
python godot/tools/import_lola.py /path/to/ldem_16.img
```

Only Python's standard library is required. This produces Godot resources that are included in native exports:

- `lola_global.tres`: 720 × 360 global elevation; each cell averages an 8 × 8 block of the original data.
- `lola_south_pole.tres`: 257 × 257 bilinear samples on an azimuthal-equidistant local grid centred on
  **88° S, 30° E**, extending **75 km** each way from the centre. Coordinates are generated with spherical
  great-circle destination equations at radius 1737.4 km. North corresponds to negative game z.

The compact global grid ranges from roughly -8269.6 to +9690.1 m. The local patch ranges from
roughly -4196.7 to +6037.4 m. These are sampled/averaged product values, not higher-resolution observations.

## What the game changes

- The global atlas renders the whole Moon, with radial relief exaggerated ×15. Its colours show height,
  not photographed surface reflectance. Clicked values remain in physical metres above the reference sphere.
- The local renderer maps the 150 km-wide patch to a default 960 game-unit square and scales relative
  heights ×0.003, then adds an arbitrary local origin. Thus the local rendering is heavily compressed and
  vertically flattened. It is not suitable for engineering slope, visibility or landing-site analysis.
- Small procedural craters, rocks, regolith detail, the flattened landing apron, buildings and all resource
  signals are fictional additions. The simplified western solar-shadow zone is not computed from LOLA.
- The terrain renderer now supports larger regions via `configure_extent(limit)` before `build`.
  The current legacy mission still authorizes movement only within ±78 game units; expanding the simulation
  bounds and placing campaign objectives throughout the larger region belongs to Claude's campaign task.
- The atlas is a global planning overview, not seamless rover-level traversal of an entire spherical Moon.
- Mars terrain is still fictional on this branch. Its data import, story, storms and manual landing are
  assigned separately in `NASA_CAMPAIGN_HANDOFF.md`; this Moon work does not claim those are implemented.

Credit in displays/submissions: **NASA/GSFC/LOLA Science Team; NASA PDS Geosciences Node. Processed,
resampled and substantially scaled for Blue Horizon.** NASA data use does not imply NASA endorsement.
