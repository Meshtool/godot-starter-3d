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
import json, os, re, sys, urllib.request
from datetime import datetime, timedelta, timezone

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


def who(c):
    """Name the builder behind a commit: agents by their trailer or login, humans by login."""
    msg = c["commit"].get("message", "")
    login = (c.get("author") or {}).get("login") or c["commit"]["author"].get("name", "?")
    low = (msg + " " + login).lower()
    if re.search(r"co-authored-by:\s*claude", msg, re.I) or login.lower().startswith("claude"):
        return "Claude"
    if "copilot" in login.lower():
        return "Copilot"
    if "codex" in low:
        return "Codex"
    if login.endswith("[bot]"):
        return login[:-5]
    return login


def effort(full, since):
    e = {"commits_7d": 0, "builders": {}, "prs_open": 0, "prs_merged_7d": 0, "ci": ""}
    try:
        for c in get(f"https://api.github.com/repos/{full}/commits?since={since}&per_page=100"):
            e["commits_7d"] += 1
            b = who(c)
            e["builders"][b] = e["builders"].get(b, 0) + 1
    except Exception as ex:
        print(f"::notice::{full}: no effort commits ({ex})")
    try:
        for pr in get(f"https://api.github.com/repos/{full}/pulls?state=all&sort=updated&direction=desc&per_page=50"):
            if pr["state"] == "open":
                e["prs_open"] += 1
            elif pr.get("merged_at") and pr["merged_at"] >= since:
                e["prs_merged_7d"] += 1
    except Exception as ex:
        print(f"::notice::{full}: no effort PRs ({ex})")
    try:
        runs = get(f"https://api.github.com/repos/{full}/actions/runs?per_page=1").get("workflow_runs", [])
        if runs:
            e["ci"] = runs[0].get("conclusion") or runs[0].get("status") or ""
    except Exception as ex:
        print(f"::notice::{full}: no CI ({ex})")
    return e


def extras(full, since):
    out = {"commit": "", "commit_at": "", "items": [], "effort": effort(full, since)}
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
    since = (datetime.now(timezone.utc) - timedelta(days=7)).strftime("%Y-%m-%dT%H:%M:%SZ")
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
            row.update(extras(r["full_name"], since))
            repos.append(row)
    if not repos:
        raise RuntimeError("no repos returned")
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
