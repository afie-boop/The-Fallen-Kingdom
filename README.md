# The Fallen Kingdom

Godot 4 project configured for deployment as a browser game on Render Static Site.

## Project source

The build accepts either:
- A complete Godot project in the repository root (with `project.godot`), or
- `The-Fallen-Kingdom2.zip` in the repository root. The ZIP must contain the complete Godot project, including `project.godot`, scenes, scripts, assets and referenced resources.

At least one of these source options must be present. The current repository must contain the actual game project before a successful build is possible.

## Render deployment

A `render.yaml` Blueprint is included. In Render, create a new Blueprint from this repository, or configure a Static Site manually:

- Branch: `main`
- Build command: `bash render-build.sh`
- Publish directory: `public`

The build script downloads Godot 4.3 and its Web export template, imports the project, and exports the browser build to `public/index.html`.

Do not publish the ZIP or the raw Godot project directory. Render must publish the generated `public/` directory.

## Notes

- The Web preset is configured for single-threaded Web export.
- If the game uses external plugins or native extensions that do not support Godot Web, those dependencies must be removed or replaced before export.
- A successful export still needs browser testing, especially on Android touch controls and mobile screen sizes.
