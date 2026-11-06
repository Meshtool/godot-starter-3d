"""Refresh data/repos.json from the GitHub API (public repos only).

Runs in CI before the Godot export. Fail-safe: on any error it leaves the
committed snapshot untouched, so the build never breaks over data.
"""
import json, os, sys, urllib.request

ORGS = ["Meshtool", "RightOnPar-LLC"]
OUT = os.path.join(os.path.dirname(__file__), "..", "data", "repos.json")


def get(url):
    req = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json",
                                               "User-Agent": "mesh-city-build"})
    tok = os.environ.get("GITHUB_TOKEN")
    if tok:
        req.add_header("Authorization", f"Bearer {tok}")
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.load(r)


def main():
    repos = []
    for org in ORGS:
        for r in get(f"https://api.github.com/orgs/{org}/repos?type=public&per_page=100"):
            if r.get("private"):
                continue  # public game: never ship private repo names
            repos.append({
                "org": org, "name": r["name"], "desc": (r.get("description") or "")[:140],
                "lang": r.get("language") or "", "size": r.get("size", 0),
                "issues": r.get("open_issues_count", 0), "stars": r.get("stargazers_count", 0),
                "pushed": r.get("pushed_at") or "", "archived": bool(r.get("archived")),
                "url": r["html_url"],
            })
    if not repos:
        raise RuntimeError("no repos returned")
    from datetime import datetime, timezone
    data = {"generated": datetime.now(timezone.utc).isoformat(timespec="seconds"), "repos": repos}
    with open(OUT, "w") as f:
        json.dump(data, f, indent=1)
    print(f"repos.json refreshed: {len(repos)} repos")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # fail-safe: keep committed snapshot
        print(f"::warning::repo refresh skipped, using snapshot ({e})")
        sys.exit(0)
