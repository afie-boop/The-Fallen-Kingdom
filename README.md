# The Fallen Kingdom

Godot 4 project exported as a browser game and hosted on Render Static Site.

## Repository layout

- `The-Fallen-Kingdom2.zip` — source Godot project archive. It must contain `project.godot` and all project assets/scripts/scenes.
- `export_presets.cfg` — Web export preset used by the Render build.
- `render-build.sh` — extracts the archive, installs the matching Godot Web export template, imports resources, and exports the game to `public/`.
- `.gitignore` — excludes generated build output and caches.

## Render settings

- Service type: Static Site
- Branch: `main`
- Build command: `bash render-build.sh`
- Publish directory: `public`

Do not set the publish directory to the ZIP or the Godot source folder. Render must publish the generated `public/index.html` and its companion Web export files.

## Local project requirements

The ZIP must be a complete Godot project, not an exported APK or a partial collection of scripts. Keep `project.godot` at the project root inside the archive, with referenced `scenes/`, `scripts/`, `assets/`, and other project folders included as needed. The Web preset is configured for single-threaded Web export.
