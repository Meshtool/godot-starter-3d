import sys, json, base64, nacl.signing
from PIL import Image
doc=json.loads(Image.open(sys.argv[1]).text["meshtag"])
body=json.dumps(doc["receipt"],sort_keys=True,separators=(',',':')).encode()
try:
    nacl.signing.VerifyKey(base64.b64decode(doc["pub"])).verify(body,base64.b64decode(doc["sig"])); print("VALID", doc["receipt"]["tag"], doc["receipt"]["result"])
except Exception as e: print("INVALID", e)
