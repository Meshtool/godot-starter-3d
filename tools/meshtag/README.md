# Mesh Tag prototype

A printable 1800×900 sample ticket with an Ed25519 receipt in its PNG `meshtag`
iTXt chunk. This remains a **SAMPLE**, signed with a public throwaway demo key.
It is not issued from gameplay, and its QR links to these sample docs.

```sh
python3 -m pip install -r requirements-dev.txt
python3 tools/meshtag/make_tag.py
python3 tools/meshtag/verify_tag.py tools/meshtag/mesh-tag-sample.png --allow-sample
```

Without `--allow-sample`, the sample is rejected. For a future real receipt,
pass an issuer public key obtained from a trusted channel, never from the image:

```sh
python3 tools/meshtag/verify_tag.py run.png --trusted-key <64-hex-character-public-key>
```

The verifier checks the explicit trust anchor, algorithm, receipt content hash,
signature and replay assertion. An attacker replacing the embedded key and
re-signing cannot pass against the trusted key. The known demo key cannot sign
a non-sample receipt. Invalid input exits 1. `SAMPLE_VALID` and
`SIGNATURE_VALID` are distinct outcomes; neither validates the PNG pixels,
real-world player identity, freshness, revocation, or a live Runtime endpoint.

Real receipt issuance and its trusted public-key distribution remain the
existing Runtime proof work (DevDesk #160/#177). No signing secret belongs in
this repository, itch.io upload, or browser client.
