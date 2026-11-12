#!/usr/bin/env bash
set -euo pipefail

# Render Static Site build for a Godot 4 Web export.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$ROOT_DIR/.render-build"
TOOLS_DIR="$WORK_DIR/tools"
SRC_DIR="$WORK_DIR/source"
GODOT_VERSION="${GODOT_VERSION:-4.3}"
TEMPLATE_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable"

mkdir -p "$ROOT_DIR/public" "$WORK_DIR" "$TOOLS_DIR"

find_project_file() {
  find "$1" \
    -type d \( -name .git -o -name .godot -o -name .render-build -o -name public \) -prune -o \
    -type f -name project.godot -print -quit 2>/dev/null || true
}

# First check the common layouts already used by this repository.
PROJECT_FILE=""
if [[ -f "$ROOT_DIR/project.godot" ]]; then
  PROJECT_FILE="$ROOT_DIR/project.godot"
elif [[ -f "$ROOT_DIR/extracted/The-Fallen-Kingdom/project.godot" ]]; then
  PROJECT_FILE="$ROOT_DIR/extracted/The-Fallen-Kingdom/project.godot"
else
  # Also support other nested extraction folder names.
  PROJECT_FILE="$(find_project_file "$ROOT_DIR")"
fi

# If source files are not checked in, accept a Godot project ZIP.
if [[ -z "$PROJECT_FILE" ]]; then
  PROJECT_ZIP=""
  for candidate in \
    "$ROOT_DIR/The-Fallen-Kingdom.zip" \
    "$ROOT_DIR/The-Fallen-Kingdom2.zip" \
    "$ROOT_DIR/The-Fallen-Kingdom2.zip"; do
    if [[ -f "$candidate" ]]; then
      PROJECT_ZIP="$candidate"
      break
    fi
  done

  if [[ -n "$PROJECT_ZIP" ]]; then
    rm -rf "$SRC_DIR"
    mkdir -p "$SRC_DIR"
    echo "Extracting $PROJECT_ZIP..."
    unzip -oq "$PROJECT_ZIP" -d "$SRC_DIR"
    PROJECT_FILE="$(find_project_file "$SRC_DIR")"
  fi
fi

if [[ -z "$PROJECT_FILE" || ! -f "$PROJECT_FILE" ]]; then
  echo "ERROR: No Godot project found."
  echo "Expected project.godot at repository root, in extracted/The-Fallen-Kingdom/, elsewhere in the source tree, or inside a project ZIP."
  echo "Repository contents:"
  find "$ROOT_DIR" -maxdepth 4 -type f -name project.godot -o -name '*.zip' | head -50 || true
  exit 1
fi

PROJECT_DIR="$(dirname "$PROJECT_FILE")"
echo "Using Godot project: $PROJECT_DIR"

# Apply gameplay patches kept alongside the source archive.
if [[ -f "$ROOT_DIR/patches/apply_kingdom_fence.py" ]]; then
  python3 "$ROOT_DIR/patches/apply_kingdom_fence.py" "$PROJECT_DIR"
fi

echo "Downloading Godot ${GODOT_VERSION}..."
curl -fsSL "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" -o "$TOOLS_DIR/godot.zip"
unzip -oq "$TOOLS_DIR/godot.zip" -d "$TOOLS_DIR"
GODOT_BIN="$(find "$TOOLS_DIR" -maxdepth 2 -type f -name 'Godot_v*-stable_linux.x86_64' -print -quit)"
if [[ -z "$GODOT_BIN" ]]; then
  echo "ERROR: Godot executable not found."
  exit 1
fi
chmod +x "$GODOT_BIN"

echo "Installing Godot Web export template..."
curl -fsSL "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_export_templates.tpz" -o "$TOOLS_DIR/templates.tpz"
mkdir -p "$TOOLS_DIR/template-extract" "$TEMPLATE_DIR"
unzip -oq "$TOOLS_DIR/templates.tpz" -d "$TOOLS_DIR/template-extract"
WEB_RELEASE="$(find "$TOOLS_DIR/template-extract" -type f -name 'web_nothreads_release.zip' -print -quit)"
if [[ -z "$WEB_RELEASE" ]]; then
  echo "ERROR: Godot Web release template not found for ${GODOT_VERSION}."
  exit 1
fi
cp "$WEB_RELEASE" "$TEMPLATE_DIR/web_nothreads_release.zip"

# Use an export preset from the project first, then fall back to the repository root.
if [[ ! -f "$PROJECT_DIR/export_presets.cfg" && -f "$ROOT_DIR/export_presets.cfg" ]]; then
  cp "$ROOT_DIR/export_presets.cfg" "$PROJECT_DIR/export_presets.cfg"
fi
if [[ ! -f "$PROJECT_DIR/export_presets.cfg" ]]; then
  echo "ERROR: export_presets.cfg is missing from $PROJECT_DIR and repository root."
  exit 1
fi

echo "Importing project resources..."
GODOT_SILENCE_ROOT_WARNING=1 "$GODOT_BIN" --headless --editor --path "$PROJECT_DIR" --import

echo "Exporting browser game..."
GODOT_SILENCE_ROOT_WARNING=1 "$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-release "Web" "$ROOT_DIR/public/index.html"

if [[ ! -s "$ROOT_DIR/public/index.html" ]]; then
  echo "ERROR: Web export did not create public/index.html."
  exit 1
fi

echo "SUCCESS: Render-ready game generated in public/."
