#!/usr/bin/env bash
# Bu düğümü hub'a bağlar ve device ID'sini yazdırır.
#
#   ./scripts/join.sh <hub-ip> <hub-device-id>
#
# Düğüm yalnızca hub ile eşleşir. Hub "introducer" olarak işaretlendiği
# için ağdaki diğer düğümleri otomatik tanıtır — herkesin herkesle tek tek
# eşleşmesi gerekmez.
#
# Bu script yalnızca DÜĞÜM tarafını yapar. Hub'ın da bu düğümü tanıması
# gerekir; onu hub'da çalışan scripts/add-node.sh yapar. İki taraf da
# birbirini tanımadan bağlantı kurulmaz.
set -euo pipefail

HUB_IP="${1:-}"
HUB_ID="${2:-}"
[ -n "$HUB_IP" ] && [ -n "$HUB_ID" ] || {
  echo "kullanım: $0 <hub-ip> <hub-device-id>" >&2; exit 1; }

NODE_HOME="${MORTISE_NODE_HOME:-$HOME/.mortise}"
GUI="${MORTISE_NODE_GUI:-127.0.0.1:8384}"
CFG="$NODE_HOME/config/config.xml"
BIN="$NODE_HOME/bin/mortise"

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
  "addresses": ["tcp://$HUB_IP:22000"],
  "introducer": true,
  "autoAcceptFolders": true
}
JSON
  echo "==> hub eklendi (introducer)"
fi

connected=0
echo -n "==> bağlantı bekleniyor "
for _ in $(seq 1 20); do
  if curl -fsS -H "X-API-Key: $KEY" "http://$GUI/rest/system/connections" 2> /dev/null \
     | python3 -c "import sys,json;c=json.load(sys.stdin)['connections'].get('$HUB_ID',{});sys.exit(0 if c.get('connected') else 1)" 2> /dev/null; then
    connected=1; break
  fi
  echo -n "."
  sleep 2
done

echo
echo "Bu düğümün Device ID'si:"
"$BIN" device-id --home="$NODE_HOME/config"
echo

if [ "$connected" = 1 ]; then
  echo "Hub'a bağlanıldı. Paylaşılan klasörler kendiliğinden gelir."
else
  # Beklenen durum: hub bu düğümü henüz tanımıyor. Bağlantı, hub tarafı
  # da eklendiği anda kendiliğinden kurulur; burada tekrar bir şey
  # çalıştırmak gerekmez.
  echo "Hub henüz bu düğümü tanımıyor. Yukarıdaki ID'yi ilet; hub'da:"
  echo "  ./scripts/add-node.sh <bu-id> <isim>"
  echo "Eklendiği anda bağlantı kendiliğinden kurulur."
fi
