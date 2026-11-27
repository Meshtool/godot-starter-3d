"""Bind a replay to gameplay source and the exact exported public repo snapshot."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FILES = ("main.gd", "main.tscn", "proof_course.gd", "proof_course.tscn", "project.godot", "proof/run_model.gd",
         "proof/run_world.gd", "data/repos.json")

def manifest():
    sources = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in FILES}
    canonical = json.dumps(sources, sort_keys=True, separators=(",", ":"))
    return {"schema": "mesh-city.build.v1", "sources": sources,
            "id": "sha256:" + hashlib.sha256(canonical.encode()).hexdigest()}

if __name__ == "__main__":
    target = ROOT / "data/build.json"
    target.write_text(json.dumps(manifest(), indent=2) + "\n")
    print("Gameplay build:", manifest()["id"])
