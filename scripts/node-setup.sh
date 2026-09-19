#!/usr/bin/env bash
# Bu makineye bir Mortise düğümü kurar (macOS).
#
# Düğüm, hub'la aynı iki katmandan oluşur: altta senkron motoru, üstünde
# Mortise'ın yapılandırması. Hub'da bu katmanlama compose.yml +
# apply-defaults.sh ile kuruluyor; burada indirilen binary + LaunchAgent +
# aynı apply-defaults.sh ile.
#
# Motor binary'si `mortise` adıyla ~/.mortise/bin altına kurulur. Paket
# yöneticisiyle kurulmaz: sistemde başka adla görünen ayrı bir kurulum
# bırakmasın ve servis, process, komut adları Mortise olsun.
#
# Masaüstü uygulaması yoktur ve olmayacak — düğüm arka planda çalışır,
# yönetim web arayüzünden yapılır.
#
# FORK NOKTASI: Faz 2'de kendi binary'mize geçildiğinde değişecek yer
# aşağıdaki indirme adımıdır. Ayrıntı: docs/fork-notes.md
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NODE_HOME="${MORTISE_NODE_HOME:-$HOME/.mortise}"
GUI="${MORTISE_NODE_GUI:-127.0.0.1:8384}"
LABEL="net.mortise.node"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
BIN="$NODE_HOME/bin/mortise"
# Sürüm tek yerde tutuluyor: .env.example. Hub ve düğümler aynı sürümü
# çalıştırır, yoksa protokol uyuşmazlığı riski doğar.
VER="${MORTISE_VERSION:-$(sed -n 's|^MORTISE_VERSION=||p' "$REPO/.env.example")}"

[ "$(uname)" = "Darwin" ] || { echo "bu script macOS içindir" >&2; exit 1; }
case "$(uname -m)" in
  arm64)  ARCH=arm64 ;;
  x86_64) ARCH=amd64 ;;
  *) echo "desteklenmeyen mimari: $(uname -m)" >&2; exit 1 ;;
esac

mkdir -p "$NODE_HOME"/bin "$NODE_HOME"/config "$NODE_HOME"/data "$NODE_HOME"/logs

# 1) Motor
if [ -x "$BIN" ] && "$BIN" --version 2>/dev/null | grep -q "v$VER"; then
  echo "==> motor  : v$VER zaten kurulu"
else
  echo "==> motor  : v$VER indiriliyor ($ARCH)"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  base="https://github.com/syncthing/syncthing/releases/download/v$VER"
  pkg="syncthing-macos-$ARCH-v$VER.zip"

  curl -fsSL "$base/$pkg" -o "$tmp/pkg.zip"
  curl -fsSL "$base/sha256sum.txt.asc" -o "$tmp/sums"

  # Checksum aynı kaynaktan geliyor, yani imza doğrulaması değil; bozuk
  # veya yarım inmiş bir paketi yakalar.
  want="$(grep -F "$pkg" "$tmp/sums" | awk '{print $1}' | head -1)"
  got="$(shasum -a 256 "$tmp/pkg.zip" | awk '{print $1}')"
  [ -n "$want" ] || { echo "checksum listesinde $pkg bulunamadı" >&2; exit 1; }
  [ "$want" = "$got" ] || { echo "checksum uyuşmadı — indirme bozuk" >&2; exit 1; }

  unzip -q "$tmp/pkg.zip" -d "$tmp"
  install -m 755 "$tmp/syncthing-macos-$ARCH-v$VER/syncthing" "$BIN"
  echo "==> motor  : kuruldu"
fi
echo "==> home   : $NODE_HOME"

# 2) LaunchAgent — login'de açılır, çökerse yeniden başlar
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$BIN</string>
    <string>serve</string>
    <string>--home=$NODE_HOME/config</string>
    <string>--no-browser</string>
    <string>--no-restart</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$NODE_HOME/logs/node.log</string>
  <key>StandardErrorPath</key><string>$NODE_HOME/logs/node.err</string>
</dict>
</plist>
PLIST

launchctl unload "$PLIST" 2> /dev/null || true
launchctl load "$PLIST"
echo "==> servis : $LABEL (login'de otomatik açılır)"

# 3) API'nin ayağa kalkmasını bekle. İlk denemeler servis açılana kadar
#    başarısız olur; sessiz tutulup sonuç tek satırda bildiriliyor.
if curl -fs --retry 30 --retry-delay 1 --retry-connrefused --retry-all-errors \
     -o /dev/null "http://$GUI/rest/noauth/health"; then
  echo "==> API    : hazır ($GUI)"
else
  echo "API ayağa kalkmadı. Log: $NODE_HOME/logs/node.err" >&2
  exit 1
fi

# 4) Porta cevap veren gerçekten bizim düğümümüz mü? Makinede 8384'ü tutan
#    başka bir senkron kurulumu varsa bizimki hiç açılamaz ve aşağıdaki
#    ayarlar yanlış yere uygulanırdı.
MINE="$("$BIN" device-id --home="$NODE_HOME/config")"
SERVING="$(curl -fsS -H "X-API-Key: $(sed -n 's|.*<apikey>\(.*\)</apikey>.*|\1|p' "$NODE_HOME/config/config.xml")" \
  "http://$GUI/rest/system/status" \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["myID"])')"
if [ "$MINE" != "$SERVING" ]; then
  echo "$GUI adresinde başka bir kurulum çalışıyor (device $SERVING)." >&2
  echo "MORTISE_NODE_GUI ile farklı bir port verin." >&2
  exit 1
fi

# 5) Mortise varsayılanları — hub'dakiyle aynı script. Klasör yolu burada
#    container değil, düğümün kendi data dizini.
MORTISE_CONFIG="$NODE_HOME/config/config.xml" \
MORTISE_API="http://$GUI" \
MORTISE_FOLDER_PATH="$NODE_HOME/data" \
  "$REPO/scripts/apply-defaults.sh"

echo
echo "Düğüm hazır. Device ID:"
"$BIN" device-id --home="$NODE_HOME/config"
echo
echo "Yönetim: http://$GUI   (hub için: ./scripts/tunnel.sh -> 8385)"
