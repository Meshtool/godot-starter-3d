extends RefCounted
## The same stable repo layout supplies both the renderer and the replay verifier.

static func from_repos(repos: Array) -> Array:
	var ordered := repos.duplicate(true)
	ordered.sort_custom(func(a, b): return "%s/%s" % [a.get("org", ""), a.get("name", "")] < "%s/%s" % [b.get("org", ""), b.get("name", "")])
	var groups := {}
	for repo in ordered:
		var org: String = repo.get("org", "")
		if not groups.has(org):
			groups[org] = []
		groups[org].append(repo)
	var points := []
	var ring := 0
	for org in groups:
		var group: Array = groups[org]
		var radius := 13.0 + ring * 14.0
		for i in group.size():
			var angle := TAU * float(i) / float(group.size()) + ring * 0.35
			var repo: Dictionary = group[i]
			var size := 0.8 + log(maxf(0.0, float(repo.get("size", 1))) + 1.0) * 0.22
			points.append({"id": "%s/%s" % [org, repo.get("name", "")],
				"x": roundi(cos(angle) * radius * 1000), "z": roundi(sin(angle) * radius * 1000),
				"radius": roundi((size + 4.0) * 1000)})
		ring += 1
	return points
