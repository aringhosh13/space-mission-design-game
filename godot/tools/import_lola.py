"""Reproduce compact Godot resources from NASA LOLA LDEM_16 or MOLA MEGT90N000EB.

Usage: python godot/tools/import_lola.py /path/to/ldem_16.img
       python godot/tools/import_lola.py /path/to/megt90n000eb.img --mola
The original .lbl is preserved in data/terrain; no remote access or dependencies required.
"""
import array
import hashlib
import math
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE_URL = "https://pds-geosciences.wustl.edu/lro/lro-l-lola-3-rdr-v1/lrolol_1xxx/data/lola_gdr/cylindrical/img/ldem_16.img"
WIDTH, HEIGHT = 5760, 2880
LATITUDE, LONGITUDE, HALF_EXTENT = -88.0, 30.0, 75000.0


def main():
    global LATITUDE, LONGITUDE, HALF_EXTENT, SOURCE_URL
    mola = "--mola" in sys.argv[2:]
    if mola:
        LATITUDE, LONGITUDE = 18.38, 77.58
        SOURCE_URL = "https://pds-geosciences.wustl.edu/mgs/urn-nasa-pds-mgs_mola_topography_derived/meg016/megt90n000eb.img"
    scale = 1.0 if mola else 0.5
    radius = 3396000.0 if mola else 1737400.0
    source = pathlib.Path(sys.argv[1])
    raw = source.read_bytes()
    if len(raw) != WIDTH * HEIGHT * 2:
        raise ValueError("Unexpected product length; use LDEM_16 signed 16-bit IMG")
    values = array.array("h")
    values.frombytes(raw)
    if (sys.byteorder == "little") == mola:
        values.byteswap()
    # The PDS label specifies 0.5 m/DN; OFFSET applies only to radius, not elevation.
    def sample(lat, lon):
        x = ((lon % 360) * 16 - 0.5) % WIDTH
        y = min(HEIGHT - 1, max(0, (90 - lat) * 16 - 0.5))
        ix, iy = math.floor(x), math.floor(y)
        fx, fy = x - ix, y - iy
        v00, v10 = values[iy * WIDTH + ix], values[iy * WIDTH + (ix + 1) % WIDTH]
        v01, v11 = values[min(iy + 1, HEIGHT - 1) * WIDTH + ix], values[min(iy + 1, HEIGHT - 1) * WIDTH + (ix + 1) % WIDTH]
        return ((v00 * (1 - fx) + v10 * fx) * (1 - fy) + (v01 * (1 - fx) + v11 * fx) * fy) * scale

    def write(name, width, height, samples):
        data = list(samples)
        if not all(math.isfinite(v) and -12000 < v < 30000 for v in data):
            raise ValueError("Invalid elevation conversion")
        content = ('[gd_resource type="Resource" script_class="" load_steps=2 format=3]\n\n'
                   '[ext_resource type="Script" path="res://scripts/lunar_elevation_data.gd" id="1"]\n\n'
                   '[resource]\nscript = ExtResource("1")\n'
                   f'width = {width}\nheight = {height}\n'
                   f'centre_latitude = {LATITUDE}\ncentre_longitude = {LONGITUDE}\nreal_half_extent_m = {HALF_EXTENT}\n'
                   f'source_product = "{"MEGT90N000EB V2.0" if mola else "LDEM_16 V3.1"}"\n'
                   'elevations = PackedFloat32Array(' + ','.join(f'{v:.2f}' for v in data) + ')\n')
        (output / name).write_text(content, encoding="utf-8")
        print(f"{name}: {width}x{height}, elevation {min(data):.1f}..{max(data):.1f} m")

    output = ROOT / "data" / "terrain"
    output.mkdir(parents=True, exist_ok=True)
    # Block averages (not point skipping) preserve broad relief in the low-resolution global overview.
    def global_values():
        for y in range(360):
            for x in range(720):
                yield sum(values[(y * 8 + j) * WIDTH + x * 8 + i] for j in range(8) for i in range(8)) / 64 * scale
    write("mola_global.tres" if mola else "lola_global.tres", 720, 360, global_values())
    # Azimuthal equidistant local patch centred on 88 S, 30 E. Local north is -z.
    lat0, lon0 = map(math.radians, (LATITUDE, LONGITUDE))
    def local_values():
        for row in range(257):
            for col in range(257):
                east = (col / 256 * 2 - 1) * HALF_EXTENT
                north = (1 - row / 256 * 2) * HALF_EXTENT
                distance = math.hypot(east, north) / radius
                bearing = math.atan2(east, north)
                lat = math.asin(math.sin(lat0) * math.cos(distance) + math.cos(lat0) * math.sin(distance) * math.cos(bearing))
                lon = lon0 + math.atan2(math.sin(bearing) * math.sin(distance) * math.cos(lat0), math.cos(distance) - math.sin(lat0) * math.sin(lat))
                yield sample(math.degrees(lat), math.degrees(lon))
    write("mola_jezero.tres" if mola else "lola_south_pole.tres", 257, 257, local_values())
    label = source.with_suffix(".lbl")
    if label.exists():
        (output / ("megt90n000eb.lbl" if mola else "ldem_16.lbl")).write_bytes(label.read_bytes())
    (output / ("MOLA_SOURCE_SHA256.txt" if mola else "SOURCE_SHA256.txt")).write_text(f"{hashlib.sha256(raw).hexdigest()}  {source.name}\n{SOURCE_URL}\n", encoding="utf-8")


if __name__ == "__main__":
    main()
