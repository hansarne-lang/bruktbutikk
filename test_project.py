"""
Automatisk prosjekttest for Bruktbutikk-spillet.
Kjøres etter hver endring for å fange vanlige feil før du åpner Godot.

Bruk: python test_project.py
"""

import re, csv, os, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).parent
PASS, FAIL, WARN = "✅", "❌", "⚠️"
errors = 0

def ok(msg):    print(f"  {PASS} {msg}")
def fail(msg):  global errors; errors += 1; print(f"  {FAIL} {msg}")
def warn(msg):  print(f"  {WARN} {msg}")

# ── 1. GDScript syntakssjekk ─────────────────────────────────
print("\n📝 GDScript-syntaks")
gdparse = Path.home() / ".local/bin/gdparse"
if gdparse.exists():
    for gd in ROOT.rglob("*.gd"):
        r = subprocess.run([str(gdparse), str(gd)], capture_output=True)
        if r.returncode != 0:
            fail(f"Parse-feil: {gd.relative_to(ROOT)}\n     {r.stderr.decode()[:200]}")
        else:
            ok(str(gd.relative_to(ROOT)))
else:
    warn("gdparse ikke funnet – installer med: pip install gdtoolkit")

# ── 2. Sjekk at node-stier i scripts matcher tscn ────────────
print("\n🔗 Node-stier (script vs scene)")

def get_tscn_nodes(tscn_path):
    nodes = {}
    with open(tscn_path) as f:
        for line in f:
            m = re.match(r'\[node name="(\w+)".*?parent="([^"]+)"', line)
            if m:
                name, parent = m.group(1), m.group(2)
                if parent == ".":
                    full = name
                else:
                    full = parent + "/" + name
                nodes[full] = True
    return nodes

def check_script_vs_scene(script_path, scene_path):
    if not scene_path.exists():
        warn(f"Ingen scene funnet for {script_path.name}")
        return
    nodes = get_tscn_nodes(scene_path)
    script = script_path.read_text(encoding="utf-8")
    # Finn alle $Sti/til/node
    refs = re.findall(r'\$([A-Za-z0-9_/]+)', script)
    for ref in refs:
        # Ignorer enkle variabelnavn uten /
        if "/" not in ref and ref[0].islower():
            continue
        # Strip leading CanvasLayer etc.
        if ref not in nodes:
            # Prøv uten UI/ prefiks
            stripped = re.sub(r'^UI/', '', ref)
            if stripped not in nodes and ref not in nodes:
                fail(f"{script_path.name}: '${ ref }' finnes ikke i {scene_path.name}")
                return
    ok(f"{script_path.name} ↔ {scene_path.name}")

check_script_vs_scene(
    ROOT / "scripts/main_menu/MainMenu.gd",
    ROOT / "scenes/main_menu/MainMenu.tscn"
)
check_script_vs_scene(
    ROOT / "scripts/shop/Shop.gd",
    ROOT / "scenes/shop/Shop.tscn"
)

# ── 3. Sjekk at CSV-filer finnes og er velformet ─────────────
print("\n📊 CSV-datafiler")
csv_files = {
    "items":      ["id","name","category","base_buy_price","base_sell_price"],
    "rooms":      ["id","name","type"],
    "characters": ["id","name","role"],
    "settings":   ["key","value"],
}
for name, required_cols in csv_files.items():
    path = ROOT / f"data/{name}.csv"
    if not path.exists():
        fail(f"Mangler: data/{name}.csv")
        continue
    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        try:
            headers = reader.fieldnames or []
            for col in required_cols:
                if col not in headers:
                    fail(f"data/{name}.csv mangler kolonne '{col}'")
                    break
            else:
                row_count = sum(1 for _ in reader)
                ok(f"data/{name}.csv ({row_count + 1} rader, kolonner OK)")
        except Exception as e:
            fail(f"data/{name}.csv – feil: {e}")

# ── 4. Sjekk at scene-filer refererer eksisterende scripts ───
print("\n🎬 Scene → script-referanser")
for tscn in ROOT.rglob("*.tscn"):
    content = tscn.read_text(encoding="utf-8")
    for m in re.finditer(r'path="(res://[^"]+\.gd)"', content):
        script_rel = m.group(1).replace("res://", "")
        script_path = ROOT / script_rel
        if not script_path.exists():
            fail(f"{tscn.name}: refererer til manglende script '{script_rel}'")
        else:
            ok(f"{tscn.name} → {script_rel}")

# ── 5. Sjekk prosjekt-konfig ──────────────────────────────────
print("\n⚙️  project.godot")
proj = (ROOT / "project.godot").read_text(encoding="utf-8")

main_scene_m = re.search(r'run/main_scene="([^"]+)"', proj)
if main_scene_m:
    main_scene = main_scene_m.group(1).replace("res://", "")
    if (ROOT / main_scene).exists():
        ok(f"Hovedscene funnet: {main_scene}")
    else:
        fail(f"Hovedscene mangler: {main_scene}")

for name in ["SaveManager", "DataLoader"]:
    if name in proj:
        ok(f"Autoload '{name}' registrert")
    else:
        fail(f"Autoload '{name}' mangler i project.godot")

# ── Resultat ─────────────────────────────────────────────────
print(f"\n{'='*45}")
if errors == 0:
    print(f"{PASS} Alle sjekker bestått – trygt å teste i Godot!")
else:
    print(f"{FAIL} {errors} feil funnet – fiks disse før du kjører i Godot.")
sys.exit(0 if errors == 0 else 1)
