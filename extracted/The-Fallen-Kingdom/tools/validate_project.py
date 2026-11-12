#!/usr/bin/env python3
"""Static sanity checks for the Godot project (does NOT replace opening it in Godot).

Checks: every res:// path exists, scene ext_resource ids resolve, autoload scripts
exist, no mixed tabs/spaces indentation in .gd files, balanced brackets, class_name
uniqueness, and that identifiers used as class names are defined.
Run from anywhere:  python3 tools/validate_project.py
"""
import re, sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
errors, warnings = [], []

def err(m): errors.append(m)

# project.godot
pg = (root / "project.godot").read_text()
for key in ("run/main_scene", "config/icon"):
    m = re.search(rf'^{re.escape(key)}="(res://[^"]+)"', pg, re.M)
    if not m: err(f"project.godot: missing {key}")
    elif not (root / m.group(1)[6:]).exists(): err(f"project.godot: {key} -> missing file {m.group(1)}")
for name, path in re.findall(r'^(\w+)="\*(res://[^"]+)"', pg, re.M):
    if not (root / path[6:]).exists(): err(f"autoload {name}: missing {path}")

gd_files = sorted(root.rglob("*.gd"))
tscn_files = sorted(root.rglob("*.tscn"))

class_names = {}
for f in gd_files:
    text = f.read_text()
    m = re.search(r"^class_name\s+(\w+)", text, re.M)
    if m:
        if m.group(1) in class_names: err(f"duplicate class_name {m.group(1)}")
        class_names[m.group(1)] = f

for f in gd_files:
    rel = f.relative_to(root)
    text = f.read_text()
    lines = text.splitlines()
    uses_tab = any(l.startswith("\t") for l in lines)
    uses_space = any(re.match(r" +\S", l) for l in lines)
    if uses_tab and uses_space: err(f"{rel}: mixed tab/space indentation")
    # strip strings/comments for bracket check
    stripped = re.sub(r'"(?:\\.|[^"\\])*"', '""', text)
    stripped = re.sub(r"#.*", "", stripped)
    for o, c in ("()", "[]", "{}"):
        if stripped.count(o) != stripped.count(c): err(f"{rel}: unbalanced {o}{c}")
    for m in re.finditer(r'res://[A-Za-z0-9_./-]+(%[0-9a-z]*)?', text):
        p = re.sub(r'%.*$', '', m.group(0))
        if m.group(1) or p.endswith("_"):   # format-string prefix like tree_%02d.png: check the folder only
            if not (root / p[6:]).parent.exists(): err(f"{rel}: missing folder for {p}")
            continue
        if not (root / p[6:]).exists(): err(f"{rel}: missing resource {p}")
    for lineno, l in enumerate(lines, 1):
        if l.rstrip() != l: pass
        if re.match(r"\s*(func|if|elif|else|for|while|match|class)\b.*[^:,\\(\[{]\s*$", l) and not l.strip().startswith("#") \
           and not l.strip().endswith(":") and "func" in l.split()[:1] and "->" in l and not l.rstrip().endswith(":"):
            err(f"{rel}:{lineno}: func line without trailing colon")

for f in tscn_files:
    rel = f.relative_to(root)
    text = f.read_text()
    ids = set(re.findall(r'\[ext_resource[^\]]*\bid="([^"]+)"', text))
    for p in re.findall(r'path="(res://[^"]+)"', text):
        if not (root / p[6:]).exists(): err(f"{rel}: missing resource {p}")
    for used in re.findall(r'ExtResource\("([^"]+)"\)', text):
        if used not in ids: err(f"{rel}: ExtResource {used} not declared")

# class names referenced but not defined (rough: capitalised words followed by .new( / as X / : X)
builtin = set("""Node Node2D Control CanvasLayer CanvasModulate CharacterBody2D StaticBody2D Area2D Sprite2D Camera2D
CollisionShape2D CircleShape2D RectangleShape2D Label Button ColorRect TextureRect CenterContainer VBoxContainer
ConfirmationDialog Gradient Image ImageTexture Texture2D PackedScene RefCounted Tween Font InputEvent InputEventKey
InputEventScreenTouch InputEventScreenDrag InputEventMouseButton InputEventMouseMotion Vector2 Color Rect2 Array
Dictionary String PackedStringArray PackedFloat32Array RandomNumberGenerator FileAccess DirAccess JSON Time
DisplayServer ThemeDB Input Engine OS Variant Object Callable Signal ShaderMaterial Shader FastNoiseLite Vector4 Vector2i Rect2i ResourceLoader PackedByteArray""".split())
for f in gd_files:
    text = f.read_text()
    for name in set(re.findall(r"\b(?:as|is)\s+([A-Z]\w+)|\b([A-Z]\w+)\.new\(", text) and
                    [a or b for a, b in re.findall(r"\b(?:as|is)\s+([A-Z]\w+)|\b([A-Z]\w+)\.new\(", text)]):
        if name not in class_names and name not in builtin:
            warnings.append(f"{f.relative_to(root)}: class '{name}' not defined by class_name (check it's a built-in)")

print(f"Checked {len(gd_files)} scripts, {len(tscn_files)} scenes, {len(class_names)} class_names.")
for w in warnings: print("WARN ", w)
for e in errors: print("ERROR", e)
print("RESULT:", "FAILED" if errors else "static checks passed (this is NOT a Godot run)")
sys.exit(1 if errors else 0)
