"""Régénère tous les packs JSON depuis tools/content_src/ et met à jour index.json.

Usage : python tools/build_content.py   (puis python tools/check_content.py)
"""
import importlib.util
import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "tools/content_src"
OUT = ROOT / "app/assets/content/packs"
sys.path.insert(0, str(SRC))

packs = []
# pack de démonstration de la phase 1 (script autonome)
subprocess.run([sys.executable, str(SRC / "demo_complexes_impedances.py")], check=True, stdout=subprocess.DEVNULL)
packs.append("packs/demo-complexes-impedances.json")

for f in sorted((SRC / "packs").glob("*.py")):
    spec = importlib.util.spec_from_file_location(f.stem, f)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    pk = mod.PACK
    dest = OUT / f"{pk['id']}.json"
    dest.write_text(json.dumps(pk, ensure_ascii=False, indent=1), encoding="utf-8")
    packs.append(f"packs/{dest.name}")
    print(f"{dest.name:45} {len(pk['courses']):3} cours {len(pk['examples']):3} exemples {len(pk['exercises']):3} exercices")

(ROOT / "app/assets/content/index.json").write_text(json.dumps({"packs": packs}, ensure_ascii=False, indent=1) + "\n",
                                                    encoding="utf-8")
print(f"{len(packs)} packs dans index.json")
