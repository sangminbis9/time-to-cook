# Pixel art refresh — final production brief

Tool: OpenAI built-in `image_gen`, not the API/CLI fallback. Source PNGs are preserved here; runtime resources are in `game/rebuild/assets/jp/`. These are reusable production prompts recording the final art direction and atlas ordering. `IMPORT_MANIFEST.json` records every native resource, anchor, and city mapping.

## Shared visual and camera constraints

Original cozy Japanese 16-bit life simulation pixel art. Carefully clustered pixels, warm wood, indigo textiles, cream highlights, muted natural colors, readable silhouettes and rich material details. No copied game assets, logos, text or watermarks. Transparent background for object atlases. Aligned orthographic overhead camera: look down at 70–75 degrees from the horizontal, showing mostly the upper surfaces and only a shallow lower edge. No isometric diamonds or vanishing-point perspective. Tables show their entire tabletop, chairs show their seat, appliances show their top. Cars are true 90-degree roof view. Characters show the crown of their head and shoulders, short foreshortened bodies. This is a playable top-down game, not a frontal illustration.

## Final source sheets

- `overhead/furniture.png`: 6 columns × 6 rows of separately spaced restaurant props. Row order: stock, board, batter, fryer, plate, counter; fridge, table, bench, door, stairs, kiosk; plant, extinguisher, generator, vent, drain, locker; climate, lounge, meal, drink, toilet, arcade; shower, wall block, lamp, chair, parking, elevator; window, noren, crockery, lantern, rug, wall menu. Include believable utensils, ingredients, worn wood, steel grilles and wicker. Large visible upper surfaces. Source: `exec-0bccb7cc-ecad-43a1-b8af-188d59395da9.png`.
- `overhead/heroes.png`: exact 4 columns × 4 rows. Columns: Hana (chestnut bob, sage apron), Jun (black hair, rust apron), Bori (mustard bandana, blue work clothes), Sora (auburn braid, indigo apron). Rows: down, left, right, up. Consistent scale, restrained overhead anatomy, head crowns visible. Source: `exec-65501214-bf31-4080-8b1a-3628c99b3e13.png`.
- `overhead/npcs.png`: 8 columns × 4 rows, eight varied neighborhood customers and workers with coherent proportions. Rows down, left, right, up. Hair crowns and shoulders dominate the overhead silhouette. Source: `exec-981ae951-3888-4c0c-9a4b-7a91ef3c91d5.png`.
- `overhead/cars.png`: exact 5 columns × 4 rows. Sage used hatchback, cream compact, blue sedan, warm white cargo van, plum electric car. Rows down, left, right, up. True roof view, full roof, windshield, hood and small bumpers; no side profiles. Source: `exec-ce9c1b4a-cf25-4fca-aa12-cf23fd1c50ce.png`.
- `overhead/exteriors.png`: 4 columns × 3 rows. Restaurant, grocery, wooden house, plaster house; rear facade, produce shelf, pantry shelf, checkout; cherry tree, utility pole, fence, vending machine. Roof-dominant overhead buildings; shelf contents seen from above. Source: `exec-445baaad-e0a5-4e14-bfe7-e365be4c5c9c.png`.
- `terrain.png`: 4 × 4 seamless opaque tile swatches: honey wood, pale kitchen tile, plaster/wood wall, grass; asphalt, stone paving, water, dark wood; tatami, moss, gravel, red roof; dashed asphalt, timber side wall, flowers, dark roof. Texture details support the object silhouettes. Source: `exec-18abefc8-4cc0-4ff5-93ea-89d2dd69e069.png`.
- `food.png`: 8 × 4 isolated top-down icons: raw chicken through cooking quality stages and serving trays; sweet/spicy/soy/garlic/teriyaki/citrus dishes and ingredients; sauces, rice, tea and scallions; dirty dishes in three severities, steam, bell, coin, basket and cleaning cloth. Source: `exec-d33977a3-fad4-495d-83b3-dafbab537e1b.png`.
- `ui.png`: 4 × 4 pixel UI elements with clear quiet centers and wood/paper borders: cream panel, indigo panel, cream button, sage hover; pressed, disabled, order ticket, HUD; inventory slot, selected slot, speech bubble, banner; coin, clock, research and flower icons. Source: `exec-96b23030-08e9-4b5d-8c44-16ee2c1e86b1.png`.
- `title.png`: landscape pixel illustration of a coastal restaurant at blue-hour dusk, red roof, indigo noren, glowing paper lanterns and windows, two chefs serving chicken, sage hatchback and lush plants. Quiet dark left area for menu and title; no baked-in letters. This illustration is key art rather than a gameplay camera reference. Source: `exec-632c6c27-66b2-4dc0-92ee-38aea2fa55f4.png`.
- `map.png`: wide hand-crafted pixel illustrated travel map of South Korea and Japan, Korea at left, Japan across right, Jeju below Korea, island coastlines, tiny mountains, villages, ocean and parchment corners; no labels baked in. Stylized navigation illustration, not a survey map. Source: `exec-d99ce449-55c4-49b6-83ff-c591622bcf3c.png`.

## Regional furniture sheets

Each final sheet is exactly 8 columns × 4 rows. Columns: table, chair, bench/worktop, counter, fridge, threshold/door, plant, lamp. Every row is a coherent regional set under the same overhead camera. Distinguish construction, tabletop silhouette, upholstery, craft patterns, plant species and lighting, not only hue. Tabletops and chair seats must remain prominent.

| Source | Row | City | Design brief |
|---|---|---|---|
| `overhead/kr_a.png` | 1 | Incheon | Open-port heritage: weathered dark wood, brass, navy maritime textiles |
| | 2 | Seoul | Contemporary hanok: pale wood, white linen, clean modern edges |
| | 3 | Busan | Harbor: blue painted timber, rope, coastal stripes |
| | 4 | Daegu | Textile craft: bojagi patchwork, burgundy wood, woven cushions |
| `overhead/kr_b.png` | 1 | Daejeon | Honey oak and mint retro cafe details |
| | 2 | Gwangju | Bamboo craft, celadon ceramics, natural weave |
| | 3 | Ulsan | Riveted steel, reclaimed wood, restrained industrial accents |
| | 4 | Jeju | Dark basalt, rattan, citrus wood and orange fruit details |
| `overhead/jp_a.png` | 1 | Tokyo | Edo indigo cloth, dark chestnut timber, compact city eatery |
| | 2 | Yokohama | Historic port parlor, green glass and Western wood furniture |
| | 3 | Osaka | Showa diner, red vinyl seats, chrome and lively checks |
| | 4 | Nagoya | Olive textiles, subtle gold accents and polished wood |
| `overhead/jp_b.png` | 1 | Sapporo | Birch, warm wool upholstery, cool northern cream |
| | 2 | Fukuoka | Hakata woven stripes, yatai cedar, festival warmth |
| | 3 | Kyoto | Machiya lattice, rattan, washi lamps, understated tea setting |
| | 4 | Kobe | Teak, burgundy leather, brass, classic port cafe |

Final regional source IDs: kr_a `exec-3fb095ec-1db0-4860-b325-24d57f89bfb0.png`; kr_b `exec-3a5205a5-ac94-4801-bebc-98d582e39420.png`; jp_a `exec-948b1568-0ced-4a62-b00f-134881df8246.png`; jp_b `exec-eb87863c-8d49-4735-83e8-921ac85b9798.png`.

## Import and rejected studies

`scripts/import_pixel_art.py` detects transparent atlas gutters, slices the authored bitmap objects, trims alpha, limits the native sprite palette, and uses nearest-neighbor sizing. It does not construct objects from drawing primitives. World tiles are 32×32, people use 32×40 directional frames, cars 48×48. Walk cycles reuse the authored directional pose with a restrained 1px gait; these are not separately drawn limb-animation frames.

Root-level `furniture.png`, `heroes.png`, `npcs.png`, `cars.png`, and `exteriors.png` are rejected frontal camera studies, retained for provenance only. They are never imported by the runtime pipeline. The corrected versions are exclusively in `overhead/`.
