"""Refresh data/repos.json from the GitHub API (public repos only).

Runs in CI before the Godot export. Fail-safe: on any error it leaves the
committed snapshot untouched, so the build never breaks over data.

Per repo it pulls what the game shows on the tower itself:
  - the latest commit (message + date) -> the tower's ticker
  - open issue / PR titles              -> one named orb each
  - topics + homepage                   -> the card
Per-repo extras are best-effort: if one call fails, that repo just ships
without them.
"""
import json, os, sys, urllib.request

ORGS = ["Meshtool", "RightOnPar-LLC"]
OUT = os.path.join(os.path.dirname(__file__), "..", "data", "repos.json")
MAX_ITEMS = 6  # named orbs per tower; the rest still count via `issues`


def get(url):
    req = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json",
                                               "User-Agent": "mesh-city-build"})
    tok = os.environ.get("GITHUB_TOKEN")
    if tok:
        req.add_header("Authorization", f"Bearer {tok}")
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.load(r)


def first_line(s, n=90):
    s = (s or "").strip().splitlines()[0] if (s or "").strip() else ""
    return s[:n]


def extras(full):
    out = {"commit": "", "commit_at": "", "items": []}
    try:
        c = get(f"https://api.github.com/repos/{full}/commits?per_page=1")
        if c:
            out["commit"] = first_line(c[0]["commit"]["message"])
            out["commit_at"] = c[0]["commit"]["committer"]["date"]
    except Exception as e:
        print(f"::notice::{full}: no commit ({e})")
    try:
        for it in get(f"https://api.github.com/repos/{full}/issues?state=open&per_page={MAX_ITEMS}"):
            out["items"].append({
                "n": it["number"], "title": first_line(it["title"], 80),
                "pr": "pull_request" in it, "url": it["html_url"],
            })
    except Exception as e:
        print(f"::notice::{full}: no issues ({e})")
    return out


def main():
    repos = []
    for org in ORGS:
        for r in get(f"https://api.github.com/orgs/{org}/repos?type=public&per_page=100"):
            if r.get("private"):
                continue  # public game: never ship private repo names
            row = {
                "org": org, "name": r["name"], "desc": (r.get("description") or "")[:140],
                "lang": r.get("language") or "", "size": r.get("size", 0),
                "issues": r.get("open_issues_count", 0), "stars": r.get("stargazers_count", 0),
                "pushed": r.get("pushed_at") or "", "archived": bool(r.get("archived")),
                "url": r["html_url"], "topics": (r.get("topics") or [])[:5],
                "homepage": r.get("homepage") or "",
            }
            row.update(extras(r["full_name"]))
            repos.append(row)
    if not repos:
        raise RuntimeError("no repos returned")
    from datetime import datetime, timezone
    data = {"generated": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "self": "Meshtool/godot-starter-3d", "repos": repos}
    with open(OUT, "w") as f:
        json.dump(data, f, indent=1)
    print(f"repos.json refreshed: {len(repos)} repos")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # fail-safe: keep committed snapshot
        print(f"::warning::repo refresh skipped, using snapshot ({e})")
        sys.exit(0)
