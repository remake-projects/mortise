#!/usr/bin/env bash
# Hub'ın YENİ klasör varsayılanlarını uygular. Mevcut klasörlere dokunmaz.
#
# Senkron motorunun kendi varsayılanları hub topolojisi için güvensiz:
#
#   versioning  : kapalı — hub'da silinen dosyanın geri dönüşü olmaz
#   minDiskFree : %1     — 50 GB'lık diskte 500 MB. Motor bu eşiğe
#                          kadar yazmaya devam eder; disk dolarsa yalnız
#                          Mortise değil, sunucudaki bütün stack'ler düşer.
#   path        : boş    — autoAcceptFolders ile gelen klasör kök dizine
#                          açılmaya çalışılır ve "mkdir /<ad>: permission
#                          denied" ile düşer. Hub'ın en sessiz kırığı budur:
#                          cihaz bağlanır, klasör asla gelmez.
#
# Ayrıca kullanım ve çökme raporları kapatılır. Arayüz Mortise adını
# taşıyor; açık kalsalar "Mortise geliştiricilere rapor gönderir" diye
# soracaklardı, oysa raporlar upstream'in sunucularına gidiyor. Adı
# değiştirilmiş bir arayüzde bu soru yanıltıcı olurdu.
#
# Sunucuda çalıştırılır:  ./scripts/apply-defaults.sh
set -euo pipefail

CONFIG="${MORTISE_CONFIG:-/opt/mortise/config/config.xml}"
API_URL="${MORTISE_API:-http://127.0.0.1:8384}"

# Silinen/değiştirilen sürümlerin saklanma süresi. Üst sınırın *var olması*
# esas; staggered zaten eskidikçe seyrekleştirir.
MAX_AGE_DAYS="${MORTISE_MAX_AGE_DAYS:-30}"
# Boş alan bu eşiğin altına inince klasöre yazma durdurulur.
MIN_DISK_FREE_GB="${MORTISE_MIN_DISK_FREE_GB:-5}"
# autoAccept ile gelen klasörlerin açılacağı dizin (container içi yol).
FOLDER_PATH="${MORTISE_FOLDER_PATH:-/var/syncthing/data}"
# Dosya değişikliğinin yayılmadan önce beklediği süre. Motor varsayılanı
# 10 sn; ortak vault'ta bu pencere iki kişinin aynı notu çakıştırması için
# fazla geniş. Vault'lar küçük olduğu için 3 sn'nin maliyeti yok.
FSWATCHER_DELAY_S="${MORTISE_FSWATCHER_DELAY_S:-3}"

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
  "path": "$FOLDER_PATH",
  "fsWatcherEnabled": true,
  "fsWatcherDelayS": $FSWATCHER_DELAY_S
}
JSON

# urAccepted = -1: kullanım raporu reddedildi, onay penceresi bir daha
# açılmaz. 0 bırakılsa arayüz ilk açılışta soruyor.
curl -fsS -X PATCH \
  -H "X-API-Key: $api_key" \
  -H "Content-Type: application/json" \
  --data '{"urAccepted": -1, "crashReportingEnabled": false}' \
  "$API_URL/rest/config/options" > /dev/null

echo "Uygulandı. Hub'ın yeni klasör varsayılanları:"
curl -fsS -H "X-API-Key: $api_key" "$API_URL/rest/config/defaults/folder" \
  | python3 -c 'import sys,json
d = json.load(sys.stdin)
v = d["versioning"]
print("  versioning :", v["type"] or "(yok)", v["params"])
print("  minDiskFree:", d["minDiskFree"]["value"], d["minDiskFree"]["unit"])
print("  path       :", repr(d["path"]))
print("  fsWatcher  :", d["fsWatcherEnabled"], "/", d["fsWatcherDelayS"], "sn")'
curl -fsS -H "X-API-Key: $api_key" "$API_URL/rest/config/options" \
  | python3 -c 'import sys,json
o = json.load(sys.stdin)
print("  raporlar   : kullanım", "kapalı" if o["urAccepted"] < 0 else o["urAccepted"],
      "/ çökme", "açık" if o["crashReportingEnabled"] else "kapalı")'
