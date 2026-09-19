#!/usr/bin/env bash
# Hub'a yeni bir düğüm tanıtır ve hub'daki klasörleri onunla paylaşır.
#
#   ./scripts/add-node.sh <device-id> <isim>
#
# Sunucuda, /opt/mortise içinde çalıştırılır. Düğüm tarafının karşılığı
# scripts/join.sh; iki taraf da birbirini tanımadan bağlantı kurulmaz.
#
# Klasörler otomatik paylaşılır: vault ortak, hub'daki her klasör ağdaki
# düğümlere açıktır.
set -euo pipefail

DEV_ID="${1:-}"
NAME="${2:-}"
[ -n "$DEV_ID" ] && [ -n "$NAME" ] || {
  echo "kullanım: $0 <device-id> <isim>" >&2; exit 1; }

CONFIG="${MORTISE_CONFIG:-/opt/mortise/config/config.xml}"
API_URL="${MORTISE_API:-http://127.0.0.1:8384}"
KEY="$(sed -n 's|.*<apikey>\(.*\)</apikey>.*|\1|p' "$CONFIG")"
[ -n "$KEY" ] || { echo "apikey okunamadı: $CONFIG" >&2; exit 1; }

DEV_ID="$DEV_ID" NAME="$NAME" API_URL="$API_URL" KEY="$KEY" python3 <<'PY'
import json, os, urllib.request

dev_id, name = os.environ["DEV_ID"], os.environ["NAME"]
api, key = os.environ["API_URL"], os.environ["KEY"]

def call(path, method="GET", body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(api + path, data=data, method=method,
                                 headers={"X-API-Key": key,
                                          "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=20) as r:
        raw = r.read()
        return json.loads(raw) if raw.strip() else None

devices = call("/rest/config/devices")
if dev_id in [d["deviceID"] for d in devices]:
    print("==> düğüm zaten tanımlı")
else:
    call("/rest/config/devices", "POST",
         {"deviceID": dev_id, "name": name, "addresses": ["dynamic"],
          "autoAcceptFolders": True})
    print("==> düğüm eklendi: %s" % name)

shared = []
for f in call("/rest/config/folders"):
    ids = [d["deviceID"] for d in f["devices"]]
    if dev_id not in ids:
        call("/rest/config/folders/%s" % f["id"], "PATCH",
             {"devices": f["devices"] + [{"deviceID": dev_id}]})
        shared.append(f["id"])
print("==> paylaşılan klasörler: %s" % (", ".join(shared) if shared else "(değişiklik yok)"))
PY
