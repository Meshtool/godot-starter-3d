import base64
import hashlib
import importlib.util
from pathlib import Path
import subprocess
import sys
import unittest
from nacl.signing import SigningKey

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("verify_tag", ROOT / "tools/meshtag/verify_tag.py")
tag = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tag)

def document(key, sample=False):
    receipt = {"v": 1, "kind": "game.run", "sample": sample, "replay": "match", "result": {"time_ms": 200}}
    body = tag.canonical(receipt)
    return {"receipt": receipt, "alg": "ed25519", "pub": base64.b64encode(key.verify_key.encode()).decode(),
            "sig": base64.b64encode(key.sign(body).signature).decode(),
            "cid": "sha256:" + hashlib.sha256(body).hexdigest()}

class TagTests(unittest.TestCase):
    def setUp(self):
        self.issuer = SigningKey.generate()
        self.doc = document(self.issuer)
        self.key = self.issuer.verify_key.encode()

    def test_trusted_signature(self):
        self.assertEqual(tag.verify_document(self.doc, self.key)["status"], "SIGNATURE_VALID")

    def test_embedded_key_does_not_establish_trust(self):
        with self.assertRaises(ValueError): tag.verify_document(self.doc)

    def test_attacker_cannot_replace_key_and_resign(self):
        with self.assertRaises(ValueError): tag.verify_document(document(SigningKey.generate()), self.key)

    def test_changed_receipt(self):
        self.doc["receipt"]["result"]["time_ms"] = 1
        with self.assertRaises(ValueError): tag.verify_document(self.doc, self.key)

    def test_rehashed_tampering_still_fails_signature(self):
        self.doc["receipt"]["result"]["time_ms"] = 1
        self.doc["cid"] = "sha256:" + hashlib.sha256(tag.canonical(self.doc["receipt"])).hexdigest()
        with self.assertRaises(Exception): tag.verify_document(self.doc, self.key)

    def test_algorithm_rejected(self):
        self.doc["alg"] = "none"
        with self.assertRaises(ValueError): tag.verify_document(self.doc, self.key)

    def test_sample_needs_opt_in(self):
        key = SigningKey(hashlib.sha256(b"MESHTAG-DEMO-KEY-NOT-REAL").digest())
        with self.assertRaises(ValueError): tag.verify_document(document(key, True))
        self.assertEqual(tag.verify_document(document(key, True), allow_sample=True)["status"], "SAMPLE_VALID")

    def test_demo_key_cannot_sign_real_run(self):
        key = SigningKey(hashlib.sha256(b"MESHTAG-DEMO-KEY-NOT-REAL").digest())
        with self.assertRaises(ValueError): tag.verify_document(document(key), tag.DEMO_KEY, True)

    def test_invalid_cli_exits_nonzero(self):
        result = subprocess.run([sys.executable, str(ROOT / "tools/meshtag/verify_tag.py"), "missing.png"], capture_output=True)
        self.assertEqual(result.returncode, 1)

    def test_shipped_sample_is_not_live_proof(self):
        result = subprocess.run([sys.executable, str(ROOT / "tools/meshtag/verify_tag.py"), str(ROOT / "tools/meshtag/mesh-tag-sample.png")], capture_output=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"SAMPLE", result.stderr)

if __name__ == "__main__":
    unittest.main()
