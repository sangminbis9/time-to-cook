# Cozy 3/4 source artwork

Original raster artwork generated with the built-in `imagegen` tool for this project. Exact prompts are in `prompts.json`; source PNGs are retained here. `architecture.png` is the corrected orthographic revision: the rejected diagonal concept is not used at runtime. The vehicle source contains exploratory categories; only the hatchback, compact and van rows are imported. `vehicle_corrections.png` supplies the actual sedan and sports EV categories without changing prices or specifications.

Runtime files are imported by `scripts/import_cozy_art.py` into `game/rebuild/assets/cozy/`. The importer cleans transparency, crops isolated atlas cells, uses nearest-neighbor sizing and packs authored animation frames. It does not draw furniture, quantize the palette, or manufacture animation from translated copies. Reviewed Jun/Sora row boundaries are in `frame_bounds.json`, because their raised cleavers overlap the otherwise empty row gutters.

Main actors use 32×48 frames. Rows 0–3 walk down/left/right/up, 4 carries, 5 chops, 6 cooks, 7 cleans, 8 idles, 9 interacts. Guest rows 4–7 wait, sit, eat and carry. Objects retain different sizes; terrain materials are 64×64 split into four 32px logical tiles. The manifest records image sizes, foot anchors, physical footprints and regional mappings.

The four regional sheets cover all 16 cities. Dining tables, vertical table variants, chairs, seating benches, service counters, refrigerators, plants and lamps are regional. Functional kitchen workbenches use the common kitchen collection. Architecture families and spatial layouts are separate data, so new furniture placement uses the same regional art as the initial room.
