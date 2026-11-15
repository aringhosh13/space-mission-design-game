# NASA Mars topography used in Blue Horizon

Source: NASA Mars Global Surveyor / Mars Orbiter Laser Altimeter (MOLA), archived by NASA PDS Geosciences Node.
Product **MEGT90N000EB**, version **2.0**, created **2003-04-03**; dataset **MGS-M-MOLA-5-MEGDR-L3-V1.0**.
Data description: https://pds-geosciences.wustl.edu/missions/mgs/megdr.html
Exact binary: https://pds-geosciences.wustl.edu/mgs/urn-nasa-pds-mgs_mola_topography_derived/meg016/megt90n000eb.img
Original label: https://pds-geosciences.wustl.edu/mgs/urn-nasa-pds-mgs_mola_topography_derived/meg016/megt90n000eb.lbl
Retrieved 2026-11-15. Original label and SHA-256 are bundled beside these processed resources.

Format: 5760 × 2880 signed 16-bit **big-endian**, one metre per DN, north-to-south rows, east-positive longitude,
pixel-registered 16 pixels/degree. Values are median observed **topography above the Martian areoid**, not
planetary radius and not elevation above a lunar-style reference sphere. Do not apply LOLA's 0.5 factor.
Where no shots exist, the product supplies interpolated values. The label reports profile gaps up to 12 km.
Nominal equatorial spacing is 3.705 km. It is not a wheel-level or landing-hazard map.

Reproduce with Python standard library:

```sh
python godot/tools/import_lola.py /path/to/megt90n000eb.img --mola
```

`mola_global.tres` averages 8 × 8 original bins per global cell. `mola_jezero.tres` bilinearly samples a 257 × 257
azimuthal-equidistant patch centred on 18.38° N, 77.58° E, extending 75 km each way. Mapping uses the product's
3396 km spherical radius. The local patch spans approximately -3742 to -642 m above the areoid.
This resampling does NOT increase the original information resolution.

Mars gameplay uses that measured broad relief, compressed horizontally to a 960-unit patch and vertically
by ×0.002 relative to an arbitrary local origin. Dunes, small craters, terraces, rocks, buildings, sample sites
and the Aurora Delta story are fictional overlays. It is not a reconstruction of Perseverance's actual route.
The planning lab instead uses original elevation units and physical patch distances, with no gameplay scaling.

Credit: **NASA/MGS/MOLA Science Team; NASA PDS Geosciences Node. Resampled and scaled for Blue Horizon.**
The data do not establish NASA endorsement or suitability of the route planner for operational use.
