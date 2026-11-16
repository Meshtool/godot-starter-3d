# Mesh Tag v0 (prototype)

The printable, shareable proof of a run. Think golden ticket: one look and people know it's a Meshtool run.

- **What it is:** a 6×3 in ticket (1800×900 at 300 dpi) with the run's game, lane (human or AI agent), time, replay result, build, and a QR code to verify.
- **What makes it last:** the full signed receipt (Ed25519) is stored inside the PNG (`meshtag` iTXt chunk). Anyone with the file and the public key can check it offline, with no account and without our servers.
- **Tamper check:** change one number and verification fails.

```
python3 tools/meshtag/make_tag.py      # writes mesh-tag-sample.png (demo key)
python3 tools/meshtag/verify_tag.py tools/meshtag/mesh-tag-sample.png   # VALID
```

The sample uses a throwaway **demo key** and is labeled SAMPLE. Real tags are issued only by the runtime (DevDesk #160/#177) after its replay matches.
The brand files it uses (`brand/avatar.png`) land in PR #6.
