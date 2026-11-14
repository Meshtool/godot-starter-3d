"""Refresh data/desk.json: the SHAPE of the DevDesk queue, never its words.

The game is public and desk titles talk about keys, money and accounts, so this
only ever keeps counts, states, ages and which agent holds a claim. Reads the
public aggregate endpoint in DEVDESK_EFFORT_URL. Fail-safe: no URL, or any error,
leaves the committed snapshot alone.
"""
import json, os, sys, urllib.request

OUT = os.path.join(os.path.dirname(__file__), "..", "data", "desk.json")
KEEP = {"generated", "open", "claimed", "stale_48h", "done_7d", "agents", "items"}
ITEM_KEEP = {"state", "age_h", "agent"}  # per item: no title, no id, no next-step text


def main():
    url = os.environ.get("DEVDESK_EFFORT_URL", "")
    if not url:
        print("desk.json: no DEVDESK_EFFORT_URL, keeping snapshot")
        return
    req = urllib.request.Request(url, headers={"User-Agent": "mesh-city-build"})
    with urllib.request.urlopen(req, timeout=20) as r:
        raw = json.load(r)
    data = {k: raw[k] for k in KEEP if k in raw}
    data["items"] = [{k: it[k] for k in ITEM_KEEP if k in it} for it in raw.get("items", [])][:80]
    with open(OUT, "w") as f:
        json.dump(data, f, indent=1)
    print(f"desk.json refreshed: {data.get('open', 0)} open")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"::warning::desk refresh skipped, using snapshot ({e})")
        sys.exit(0)
