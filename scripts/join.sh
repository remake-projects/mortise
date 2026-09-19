#!/usr/bin/env bash
# Bu düğümü hub'a bağlar.
#
#   ./scripts/join.sh <davet-kodu>
#
# Davet kodu hub'da ./scripts/invite.sh ile üretilir ve
# <ip>:<port>/<device-id> biçimindedir.
#
# Kendi kimliğini karşı tarafa iletmen gerekmez: bağlanmayı denediğin anda
# hub'ın bekleyenler listesine düşersin, onay orada verilir. Onaylanana
# kadar hiçbir veri alışverişi olmaz.
set -euo pipefail

CODE="${1:-}"
[ -n "$CODE" ] || {
  echo "kullanım: $0 <davet-kodu>" >&2
  echo "  kod hub'da ./scripts/invite.sh ile üretilir" >&2
  exit 1; }

HUB_ADDR="${CODE%%/*}"   # ip:port
HUB_ID="${CODE#*/}"      # device id
[ "$HUB_ADDR" != "$CODE" ] && [ -n "$HUB_ID" ] || {
  echo "davet kodu geçersiz. beklenen biçim: <ip>:<port>/<device-id>" >&2; exit 1; }

NODE_HOME="${MORTISE_NODE_HOME:-$HOME/.mortise}"
GUI="${MORTISE_NODE_GUI:-127.0.0.1:8384}"
CFG="$NODE_HOME/config/config.xml"

[ -f "$CFG" ] || {
  echo "düğüm kurulu değil — önce ./scripts/node-setup.sh" >&2; exit 1; }
KEY="$(sed -n 's|.*<apikey>\(.*\)</apikey>.*|\1|p' "$CFG")"

if curl -fsS -H "X-API-Key: $KEY" "http://$GUI/rest/config/devices" | grep -q "$HUB_ID"; then
  echo "==> hub zaten ekli"
else
  curl -fsS -X POST -H "X-API-Key: $KEY" -H "Content-Type: application/json" \
    --data @- "http://$GUI/rest/config/devices" > /dev/null <<JSON
{
  "deviceID": "$HUB_ID",
  "name": "mortise-hub",
  "addresses": ["tcp://$HUB_ADDR"],
  "introducer": true,
  "autoAcceptFolders": true
}
JSON
  echo "==> hub eklendi ($HUB_ADDR)"
fi

connected=0
echo -n "==> bağlanılıyor "
for _ in $(seq 1 15); do
  if curl -fsS -H "X-API-Key: $KEY" "http://$GUI/rest/system/connections" 2> /dev/null \
     | python3 -c "import sys,json;c=json.load(sys.stdin)['connections'].get('$HUB_ID',{});sys.exit(0 if c.get('connected') else 1)" 2> /dev/null; then
    connected=1; break
  fi
  echo -n "."
  sleep 2
done
echo

if [ "$connected" = 1 ]; then
  echo "Hub'a bağlanıldı. Paylaşılan klasörler kendiliğinden gelir."
else
  # Bağlantı kurulamadı. İki ayrı sebep olabilir ve kullanıcı için farklı
  # anlama gelirler: hub bizi henüz onaylamadı (beklenen), ya da hub'a hiç
  # ulaşamıyoruz (yanlış adres / kapalı port). TCP erişimine bakıp doğru
  # olanı söylüyoruz — yoksa ulaşılamayan bir hub sessizce "onay
  # bekleniyor" gibi görünürdü.
  if (exec 3<> "/dev/tcp/${HUB_ADDR%%:*}/${HUB_ADDR##*:}") 2> /dev/null; then
    exec 3<&- 2> /dev/null || true
    echo "Hub'a haber verildi, onay bekleniyor."
    echo "Hub tarafında onaylandığı anda bağlantı kendiliğinden kurulur."
  else
    echo "Hub'a ulaşılamıyor: $HUB_ADDR" >&2
    echo "Davet kodundaki adres doğru mu, hub çalışıyor mu kontrol edin." >&2
    echo "(Hub eklendi; adres düzelirse bağlantı kendiliğinden kurulur.)" >&2
    exit 1
  fi
fi
