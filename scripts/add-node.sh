#!/usr/bin/env bash
# Hub'a katılmak isteyen düğümleri listeler ve onaylar. Hub'da çalıştırılır.
#
#   ./scripts/add-node.sh                      # bekleyenleri listele
#   ./scripts/add-node.sh <device-id> [isim]   # onayla
#
# Device ID'nin ilk birkaç karakteri yeterlidir. İsim verilmezse düğümün
# kendi bildirdiği ad kullanılır.
#
# Onaylanan düğüm hub'daki klasörleri alır: vault ortak, hub'daki her
# klasör ağdaki düğümlere açıktır.
set -euo pipefail

CONFIG="${MORTISE_CONFIG:-/opt/mortise/config/config.xml}"
API_URL="${MORTISE_API:-http://127.0.0.1:8384}"
KEY="$(sed -n 's|.*<apikey>\(.*\)</apikey>.*|\1|p' "$CONFIG")"
[ -n "$KEY" ] || { echo "apikey okunamadı: $CONFIG" >&2; exit 1; }

DEV_ARG="${1:-}" NAME_ARG="${2:-}" API_URL="$API_URL" KEY="$KEY" python3 <<'PY'
import json, os, sys, urllib.request

api, key = os.environ["API_URL"], os.environ["KEY"]
dev_arg, name_arg = os.environ["DEV_ARG"], os.environ["NAME_ARG"]

def call(path, method="GET", body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(api + path, data=data, method=method,
                                 headers={"X-API-Key": key,
                                          "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=20) as r:
        raw = r.read()
        return json.loads(raw) if raw.strip() else None

pending = call("/rest/cluster/pending/devices") or {}

if not dev_arg:
    if not pending:
        print("Bekleyen düğüm yok.")
        print("Davet kodu üretmek için: ./scripts/invite.sh")
    else:
        print("Bekleyen düğümler:\n")
        for did, info in pending.items():
            print("  %s" % did)
            print("    ad     : %s" % (info.get("name") or "(bildirilmedi)"))
            print("    adres  : %s" % (info.get("address") or "-"))
            print("    zaman  : %s\n" % (info.get("time") or "-"))
        print("Onaylamak için: ./scripts/add-node.sh <device-id> [isim]")
    sys.exit(0)

# Kısmi ID ile eşleştir: önce bekleyenlerde, sonra tam ID olarak kabul et.
matches = [d for d in pending if d.upper().startswith(dev_arg.upper())]
if len(matches) > 1:
    print("Birden fazla eşleşme: %s" % ", ".join(m[:12] for m in matches), file=sys.stderr)
    sys.exit(1)
dev_id = matches[0] if matches else dev_arg
name = name_arg or (pending.get(dev_id, {}).get("name") if matches else "") or dev_id[:7]

if dev_id in [d["deviceID"] for d in call("/rest/config/devices")]:
    print("==> düğüm zaten tanımlı: %s" % name)
else:
    call("/rest/config/devices", "POST",
         {"deviceID": dev_id, "name": name, "addresses": ["dynamic"],
          "autoAcceptFolders": True})
    print("==> onaylandı: %s (%s)" % (name, dev_id[:12]))

shared = []
for f in call("/rest/config/folders"):
    if dev_id not in [d["deviceID"] for d in f["devices"]]:
        call("/rest/config/folders/%s" % f["id"], "PATCH",
             {"devices": f["devices"] + [{"deviceID": dev_id}]})
        shared.append(f["id"])
print("==> paylaşılan klasörler: %s" % (", ".join(shared) if shared else "(değişiklik yok)"))
PY
