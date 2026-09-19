#!/usr/bin/env bash
# Hub için davet kodu üretir. Hub'da çalıştırılır.
#
#   ./scripts/invite.sh
#
# Kod gizli değildir — hub'ın adresi ve kimliğidir, ikisi de zaten
# bağlanmak için gereken açık bilgi. Kodu ele geçiren biri hub'a
# bağlanmayı deneyebilir ama onaylanmadan hiçbir veri alamaz; onay
# scripts/add-node.sh ile verilir.
set -euo pipefail

CONFIG="${MORTISE_CONFIG:-/opt/mortise/config/config.xml}"
API_URL="${MORTISE_API:-http://127.0.0.1:8384}"
PORT="${MORTISE_SYNC_PORT:-22000}"

KEY="$(sed -n 's|.*<apikey>\(.*\)</apikey>.*|\1|p' "$CONFIG")"
[ -n "$KEY" ] || { echo "apikey okunamadı: $CONFIG" >&2; exit 1; }

ID="$(curl -fsS -H "X-API-Key: $KEY" "$API_URL/rest/system/status" \
      | python3 -c 'import sys,json; print(json.load(sys.stdin)["myID"])')"

# Hub'ın dışarıdan görünen adresi. Otomatik tespit dış bir servise
# soruyor; ağ kapalıysa MORTISE_PUBLIC_IP ile elle verilir.
IP="${MORTISE_PUBLIC_IP:-$(curl -fsS -4 -m 5 https://ifconfig.me 2> /dev/null || true)}"
[ -n "$IP" ] || {
  echo "hub'ın public IP'si bulunamadı — MORTISE_PUBLIC_IP ile verin" >&2; exit 1; }

CODE="$IP:$PORT/$ID"

cat <<TXT

Davet kodu:

  $CODE

Katılacak kişi şunları çalıştırır:

  git clone https://github.com/remake-projects/mortise.git
  cd mortise
  ./scripts/node-setup.sh
  ./scripts/join.sh $CODE

Sonrasında bu tarafta onaylanır — karşı taraftan bilgi beklemeye gerek yok,
bağlanmayı denediği anda bekleyenler listesine düşer:

  ./scripts/add-node.sh

TXT
