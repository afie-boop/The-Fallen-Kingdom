#!/usr/bin/env python3
"""Download official NYC Open Data geometry and prepare Manhattan for Godot.

The source coordinates are GeoJSON longitude/latitude. Output coordinates are
local metres centred on Manhattan, with north pointing up (negative Godot Y).
"""
import json
import math
import os
import sys
import time
import urllib.parse
import urllib.request

OUT = sys.argv[1] if len(sys.argv) > 1 else "data/nyc/manhattan.json"
BASE = "https://data.cityofnewyork.us/resource"
CENTER_LON = -73.9712
CENTER_LAT = 40.7831
METERS_PER_DEG_LAT = 111320.0
METERS_PER_DEG_LON = 111320.0 * math.cos(math.radians(CENTER_LAT))
BBOX = (40.680, -74.050, 40.890, -73.900)
PAGE = 50000


def request_page(dataset, where, offset):
    params = {"$where": where, "$limit": str(PAGE), "$offset": str(offset)}
    url = f"{BASE}/{dataset}.geojson?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(url, headers={"User-Agent": "TheFallenKingdom/1.0 map-data-builder"})
    with urllib.request.urlopen(req, timeout=120) as response:
        return json.loads(response.read().decode("utf-8"))


def fetch_all(dataset, where):
    features = []
    offset = 0
    while True:
        payload = request_page(dataset, where, offset)
        page = payload.get("features", []) if isinstance(payload, dict) else []
        if not page:
            break
        features.extend(page)
        print(f"{dataset}: received {len(features)} features", flush=True)
        if len(page) < PAGE:
            break
        offset += PAGE
        time.sleep(0.15)
    return features


def xy(coord):
    lon, lat = coord[0], coord[1]
    return [
        round((lon - CENTER_LON) * METERS_PER_DEG_LON, 2),
        round((CENTER_LAT - lat) * METERS_PER_DEG_LAT, 2),
    ]


def simplify_ring(points, tolerance=2.5):
    if len(points) <= 5:
        return points
    out = [points[0]]
    last = points[0]
    t2 = tolerance * tolerance
    for point in points[1:-1]:
        dx, dy = point[0] - last[0], point[1] - last[1]
        if dx * dx + dy * dy >= t2:
            out.append(point)
            last = point
    out.append(points[-1])
    return out


def convert_geometry(geom):
    if not geom:
        return None
    kind = geom.get("type")
    coords = geom.get("coordinates")
    if kind == "Point":
        return {"type": kind, "coordinates": xy(coords)}
    if kind == "MultiPoint":
        return {"type": kind, "coordinates": [xy(p) for p in coords]}
    if kind == "LineString":
        return {"type": kind, "coordinates": [xy(p) for p in coords]}
    if kind == "MultiLineString":
        return {"type": kind, "coordinates": [[xy(p) for p in line] for line in coords]}
    if kind == "Polygon":
        return {"type": kind, "coordinates": [simplify_ring([xy(p) for p in ring]) for ring in coords]}
    if kind == "MultiPolygon":
        return {"type": kind, "coordinates": [[simplify_ring([xy(p) for p in ring]) for ring in poly] for poly in coords]}
    return None


def pack(features, kind):
    result = []
    for feature in features:
        props = feature.get("properties") or {}
        geom = convert_geometry(feature.get("geometry") or props.get("the_geom"))
        if not geom:
            continue
        result.append({
            "kind": kind,
            "name": props.get("name") or props.get("stname_lab") or props.get("name311") or "",
            "height": props.get("height_roof") or 0,
            "year": props.get("construction_year") or 0,
            "geometry": geom,
        })
    return result


def main():
    south, west, north, east = BBOX
    box = f"within_box(the_geom,{south},{west},{north},{east})"
    print("Downloading Manhattan borough outline...", flush=True)
    boundary = fetch_all("yqww-f9f3", "borocode = 1")
    print("Downloading Manhattan building footprints...", flush=True)
    buildings = fetch_all("5zhs-2jue", "bin >= 1000000 AND bin < 2000000")
    print("Downloading Manhattan street geometry...", flush=True)
    roads = fetch_all("inkn-q76z", box)
    print("Downloading Manhattan hydrography...", flush=True)
    water = fetch_all("pjs3-c3z5", box)
    print("Downloading Manhattan parks...", flush=True)
    parks = fetch_all("enfh-gkve", "borough = 'M'")

    payload = {
        "source": "NYC Open Data",
        "projection": "local equirectangular metres; centre -73.9712,40.7831",
        "center": [CENTER_LON, CENTER_LAT],
        "boundary": pack(boundary, "boundary"),
        "buildings": pack(buildings, "building"),
        "roads": pack(roads, "road"),
        "water": pack(water, "water"),
        "parks": pack(parks, "park"),
    }
    os.makedirs(os.path.dirname(OUT) or ".", exist_ok=True)
    temp = OUT + ".tmp"
    with open(temp, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, separators=(",", ":"), ensure_ascii=False)
    os.replace(temp, OUT)
    print(
        "Manhattan data ready: "
        f"{len(payload['boundary'])} boundary, "
        f"{len(payload['buildings'])} buildings, "
        f"{len(payload['roads'])} roads, "
        f"{len(payload['water'])} water, "
        f"{len(payload['parks'])} parks -> {OUT}",
        flush=True,
    )


if __name__ == "__main__":
    main()
