"""Check embedded receipt bytes against an explicitly trusted Ed25519 key.

PNG pixels are not authenticated. The embedded key is never a trust anchor.
"""
import argparse
import base64
import hashlib
import json
import sys
from pathlib import Path

from nacl.signing import SigningKey, VerifyKey
from PIL import Image

DEMO_KEY = SigningKey(hashlib.sha256(b"MESHTAG-DEMO-KEY-NOT-REAL").digest()).verify_key.encode()
MAX_TAG_BYTES = 8 * 1024 * 1024

def canonical(receipt):
    return json.dumps(receipt, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()

def verify_document(doc, trusted_key=None, allow_sample=False):
    if not isinstance(doc, dict) or doc.get("alg") != "ed25519":
        raise ValueError("unsupported tag format or algorithm")
    receipt = doc.get("receipt")
    if not isinstance(receipt, dict) or receipt.get("kind") != "game.run" or receipt.get("v") != 1:
        raise ValueError("unsupported receipt")
    sample = receipt.get("sample") is True
    if sample and not allow_sample:
        raise ValueError("SAMPLE receipt; not a real Runtime run")
    key = DEMO_KEY if sample and allow_sample else trusted_key
    if key is None:
        raise ValueError("a trusted issuer public key is required")
    if not sample and key == DEMO_KEY:
        raise ValueError("demo key cannot authenticate a real run")
    if base64.b64decode(doc["pub"], validate=True) != key:
        raise ValueError("embedded key does not match the trusted issuer")
    body = canonical(receipt)
    if doc.get("cid") != "sha256:" + hashlib.sha256(body).hexdigest():
        raise ValueError("receipt content hash mismatch")
    VerifyKey(key).verify(body, base64.b64decode(doc["sig"], validate=True))
    if receipt.get("replay") != "match":
        raise ValueError("receipt does not attest a matching replay")
    return {"status": "SAMPLE_VALID" if sample else "SIGNATURE_VALID",
            "sample": sample, "receipt": receipt,
            "scope": "embedded receipt only; image pixels and human identity are not verified"}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("png", type=Path)
    parser.add_argument("--trusted-key", help="64 hex characters obtained from a trusted issuer, not the tag")
    parser.add_argument("--allow-sample", action="store_true")
    args = parser.parse_args()
    try:
        if args.png.stat().st_size > MAX_TAG_BYTES:
            raise ValueError("tag exceeds 8 MiB")
        key = bytes.fromhex(args.trusted_key) if args.trusted_key else None
        with Image.open(args.png) as img:
            doc = json.loads(img.text["meshtag"])
        print(json.dumps(verify_document(doc, key, args.allow_sample), sort_keys=True))
        return 0
    except Exception as exc:
        print("INVALID: " + str(exc), file=sys.stderr)
        return 1

if __name__ == "__main__":
    sys.exit(main())
