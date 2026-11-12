# The Fallen Kingdom — Stage 1 (playable foundation)

Original 2D top-down pixel-art kingdom RPG for Android, built with **Godot 4.3+** and GDScript.
Art comes from PNG files in `assets/` (plus castle and coin generated in code). No plugins are used.

> **Test status — please read:** this project was written without access to the Godot editor.
> It has **not** been opened, run, or exported to an APK by me. Only static checks were run
> (`python3 tools/validate_project.py`: file/resource paths, scene references, bracket balance).
> Expect that the first run in Godot may show a few errors to fix. Nothing here is verified on a phone.

## Open and run

1. Install Godot 4.3 (or newer 4.x) stable.
2. Unzip, then in Godot: **Import** → select `project.godot` → **Import & Edit**.
   Let Godot finish importing once (it registers the `class_name` scripts).
3. Press **F5**. Desktop controls: **WASD/arrows** move, **Space** attack, **E** use, **Esc** pause.

## Android export (from a PC)

Install the Android export templates and set up the Android SDK/JDK in Godot, then
**Project → Export → Add… → Android**. Use the *GL Compatibility* renderer (already set).
If you want the optional tuning file `data/game_config.json` in the APK, add `data/*.json`
to the export preset's *Resources → Filters to export non-resource files*. Without it the
built-in defaults are used (the game still runs).

## Controls

**Phone / tablet (touch controls are shown automatically):**
- **Joystick:** touch anywhere on the left half of the screen - the stick appears under your thumb (a faint stick shows bottom-left when idle).
- **HIT** (bottom-right, large): sword attack, also chops trees. Hold to keep attacking.
- **USE** (above-left of HIT): interact with the castle.
- **II** (top-right): pause. Android Back also opens the pause menu.

**PC (keyboard + mouse; touch controls hidden, a help line is shown instead):**
WASD / arrows move - Space or left mouse button attack (mouse aims the swing) - E use - Esc pause.
Touch-screen laptops show the touch controls as well.

## Graphics and island

- The world is a randomly shaped island (different coastline for every new game, derived from the saved world seed)
  surrounded by animated sea, with a sand beach and a grass interior. It is drawn by one shader
  (`assets/shaders/ground.gdshader`) from a mask made by `scripts/island_map.gd`. You cannot walk into the sea.
- The kingdom "castle" is now a house (`ruin_3`): respawn point, heal, deposit wood, save. The Zombie Castle is unchanged.
- Grass is one big generated realistic image (not tiled) and some areas are bare soil without grass (patches, a yard around the house and the ruins); sea, sand, trees, ruined houses and characters use the PNG files in `assets/` (see `assets/CREDITS.md`
  about licences). The player uses `char_01` (knight); set `GameState.player_skin` (1-11) to use another one.
  Zombies use a green recolour. Characters are single front-facing sprites (walk = hop + tilt + flip).
- Twelve ruined houses are scattered across the larger island as decoration with collision. Castles are drawn at 2x size.

## Zombies, nests, camps and beggars

- Zombies only appear **at night**. They crawl out of **8 small nests** scattered over the island and out of the big
  **Zombie Castle** (which spawns more). At dawn they fade away. Each zombie uses one of 11 zombie sprites.
- **5-6 poor people's camps** are placed deep inside dense jungle groves, away from the kingdom, for each new world (stored via the world seed). Every camp has exactly
  **2 tents** at random positions, a campfire, dense surrounding jungle trees and **1-2 beggars**. The four beggars outside the kingdom remain in place.
- Walk up to a beggar and press USE / E: it costs 1 Gold Coin from your own wallet and the beggar becomes a citizen
  who wanders in front of the kingdom house. Recruited beggars are saved. Farmer/knight/hunter jobs are Stage 2 (not implemented).

## Kingdom: BUILD menu, archers and builders

- Press **BUILD** (top-right, or **B** on PC) to open the menu. It pauses the game. All costs are paid from **your own wallet**
  and are small placeholder numbers in `GameConfig` / `data/game_config.json` (starting gold is 15 so you can try it).
- You can **build and upgrade**: the **Castle** (1, behind the house), **Walls** (8 segment slots around the house),
  **Archer Posts** (3) and **Builder Huts** (2). Buildings go into fixed slots (no free placement yet).
  Upgrades (Lv 1-3) apply to all buildings of that kind; Lv 2/3 of walls, posts and huts need the Castle at that level first.
- 4 beggars wait just outside the kingdom (plus 1-2 in each poor camp). Recruit them (1 coin) to get **citizens**.
- A built Archer Post / Builder Hut takes a **jobless citizen** automatically. Archers shoot zombies with arrows
  (and kill them for coin drops). Builders repair damaged **buildings, walls and the house** for free, with no materials,
  **in the daytime only** (not at night). The menu text says "morning" in the request; the design rule is "daytime".
- Zombies chew through walls/buildings in their way. A wall at 0 HP is breached (no collision) until repaired.
- Sprites: citizens, builders, archers, beggars and zombies use your character sheets (11 variants each).

## Gameplay in Stage 1

- Walk around a 4800×4800 world with collision, a camera that follows you, day/night cycle.
- Zombies come out at night from nests and the Zombie Castle and walk toward you or the kingdom house.
- Kill zombies with the sword; they sometimes drop **Gold Coins** (personal wallet).
- Chop trees for **wood** (carried). At the **castle**, **USE** deposits wood into the shared kingdom stock, heals you and saves.
- Dying: you respawn at the castle. Death penalty is configurable (`death_penalty_percent`, default 0) and only touches your own wallet.
- Save/load: autosave every 60 s, on pause, when the app goes to background, and at the castle. Chopped trees stay chopped.

## Implemented (Stage 1)

Main menu, New Game / Continue / overwrite confirmation, loading flow · top-down movement · mobile joystick and buttons ·
camera with world limits · collision · simple walk animation · player health, death, respawn · Gold Coin wallet (per player id) ·
inventory foundation (personal) + separate shared kingdom resource stock · trees/wood · basic zombie (object-pooled) ·
Zombie Castle as spawn origin · kingdom castle (HP, respawn point, heal/deposit/save) · day/night cycle ·
versioned JSON save with backup and validation of damaged data · config file with configurable undecided values.

## Not implemented yet

Farmer, knight and hunter jobs · free building placement, houses, farms · Market and trading · mines, bricks, cement, steel ·
troops and attack commands · destroying the Zombie Castle · islands · mounts · missions · seasons · dungeons ·
avatar customisation · **LAN multiplayer** (data layout is keyed by player id to prepare for it; no networking code exists) ·
audio · APK export preset · automated gameplay tests.

## Known limitations / provisional choices (not official rules)

- Wood in a personal inventory then deposited at the castle is a Stage-1 placeholder design.
- The kingdom castle cannot be destroyed in Stage 1 (HP floors at 1) and is restored at dawn.
- Zombie Castle is indestructible in Stage 1. Rebuild behaviour of destroyed bases is undecided and not implemented.
- Coin reward rule is "whoever picks it up"; real reward distribution is undecided (`reward_distribution_mode`).
- `starting_gold` (5) is a placeholder so Stage 2 recruitment can be tried.
- Placeholder pixel art is simple; a real art pass is expected later.

## Structure

```
The-Fallen-Kingdom/
  assets/   terrain/ trees/ characters/ buildings/ shaders/ CREDITS.md
  project.godot  icon.svg  README.md  .gitignore
  data/game_config.json            optional tuning overrides
  scenes/    main_menu, game, player, zombie, coin, tree, castle, enemy_castle (.tscn)
  scripts/
    autoload/ game_config.gd  game_state.gd  save_manager.gd
    game.gd main_menu.gd hud.gd player.gd zombie.gd zombie_spawner.gd
    castle.gd enemy_castle.gd zombie_nest.gd camp_prop.gd beggar.gd citizen.gd structure.gd kingdom_manager.gd arrow.gd tree.gd coin.gd day_night.gd world_generator.gd
    pixel_art.gd touch_joystick.gd touch_action_button.gd island_map.gd ruin.gd
  tools/validate_project.py        static checks
```

## Upload to GitHub from a phone

Upload `The-Fallen-Kingdom.zip` to a release, or extract it and upload the folder contents with the GitHub app/website.
`.godot/` and build outputs are already in `.gitignore`.
