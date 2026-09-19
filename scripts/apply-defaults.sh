#!/usr/bin/env bash
# Hub'ın YENİ klasör varsayılanlarını uygular. Mevcut klasörlere dokunmaz.
#
# Syncthing'in kendi varsayılanları hub topolojisi için güvensiz:
#
#   versioning  : kapalı — hub'da silinen dosyanın geri dönüşü olmaz
#   minDiskFree : %1     — 50 GB'lık diskte 500 MB. Syncthing bu eşiğe
#                          kadar yazmaya devam eder; disk dolarsa yalnız
#                          Mortise değil, sunucudaki bütün stack'ler düşer.
#   path        : boş    — autoAcceptFolders ile gelen klasör kök dizine
#                          açılmaya çalışılır ve "mkdir /<ad>: permission
#                          denied" ile düşer. Hub'ın en sessiz kırığı budur:
#                          cihaz bağlanır, klasör asla gelmez.
#
# Sunucuda çalıştırılır:  ./scripts/apply-defaults.sh
set -euo pipefail

CONFIG="${MORTISE_CONFIG:-/opt/mortise/config/config.xml}"
API_URL="${MORTISE_API:-http://127.0.0.1:8384}"

# Silinen/değiştirilen sürümlerin saklanma süresi. Üst sınırın *var olması*
# esas; staggered zaten eskidikçe seyrekleştirir.
MAX_AGE_DAYS="${MORTISE_MAX_AGE_DAYS:-30}"
# Syncthing boş alan bu eşiğin altına inince klasöre yazmayı durdurur.
MIN_DISK_FREE_GB="${MORTISE_MIN_DISK_FREE_GB:-5}"
# autoAccept ile gelen klasörlerin açılacağı dizin (container içi yol).
FOLDER_PATH="${MORTISE_FOLDER_PATH:-/var/syncthing/data}"

api_key=$(sed -n 's|.*<apikey>\(.*\)</apikey>.*|\1|p' "$CONFIG")
[ -n "$api_key" ] || { echo "apikey okunamadı: $CONFIG" >&2; exit 1; }

curl -fsS -X PATCH \
  -H "X-API-Key: $api_key" \
  -H "Content-Type: application/json" \
  --data @- \
  "$API_URL/rest/config/defaults/folder" > /dev/null <<JSON
{
  "versioning": {
    "type": "staggered",
    "params": { "maxAge": "$((MAX_AGE_DAYS * 86400))" },
    "cleanupIntervalS": 3600
  },
  "minDiskFree": { "value": $MIN_DISK_FREE_GB, "unit": "GB" },
  "path": "$FOLDER_PATH"
}
JSON

echo "Uygulandı. Hub'ın yeni klasör varsayılanları:"
curl -fsS -H "X-API-Key: $api_key" "$API_URL/rest/config/defaults/folder" \
  | python3 -c 'import sys,json
d = json.load(sys.stdin)
v = d["versioning"]
print("  versioning :", v["type"] or "(yok)", v["params"])
print("  minDiskFree:", d["minDiskFree"]["value"], d["minDiskFree"]["unit"])
print("  path       :", repr(d["path"]))'
