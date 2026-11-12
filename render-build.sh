#!/usr/bin/env bash
set -euo pipefail

# Render Static Site build for a Godot 4 Web export.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$ROOT_DIR/.render-build"
TOOLS_DIR="$WORK_DIR/tools"
SRC_DIR="$WORK_DIR/source"
PROJECT_ZIP="$ROOT_DIR/The-Fallen-Kingdom.zip"
GODOT_VERSION="${GODOT_VERSION:-4.3}"
TEMPLATE_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable"

mkdir -p "$ROOT_DIR/public" "$WORK_DIR" "$TOOLS_DIR"

# Accept either a complete Godot project at repository root or the project ZIP.
if [[ -f "$ROOT_DIR/project.godot" ]]; then
  PROJECT_DIR="$ROOT_DIR"
elif [[ -f "$PROJECT_ZIP" ]]; then
  rm -rf "$SRC_DIR"
  mkdir -p "$SRC_DIR"
  echo "Extracting $PROJECT_ZIP..."
  unzip -oq "$PROJECT_ZIP" -d "$SRC_DIR"
  PROJECT_FILE="$(find "$SRC_DIR" -type f -name project.godot -not -path '*/.godot/*' -print -quit)"
  if [[ -z "$PROJECT_FILE" ]]; then
    echo "ERROR: ZIP does not contain project.godot. Upload the complete Godot project."
    exit 1
  fi
  PROJECT_DIR="$(dirname "$PROJECT_FILE")"
else
  echo "ERROR: No Godot project found."
  echo "Add project.godot at the repository root or upload The-Fallen-Kingdom2.zip."
  exit 1
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

# Use the repository's known browser export preset.
if [[ -f "$ROOT_DIR/export_presets.cfg" && "$ROOT_DIR/export_presets.cfg" != "$PROJECT_DIR/export_presets.cfg" ]]; then
  cp "$ROOT_DIR/export_presets.cfg" "$PROJECT_DIR/export_presets.cfg"
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
