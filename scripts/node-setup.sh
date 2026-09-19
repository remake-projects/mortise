#!/usr/bin/env bash
# Bu makineye bir Mortise düğümü kurar (macOS).
#
# Düğüm, hub'la aynı iki katmandan oluşur: altta Syncthing çalışır, üstünde
# Mortise'ın yapılandırması durur. Hub'da bu katmanlama compose.yml +
# apply-defaults.sh ile kuruluyor; burada brew + LaunchAgent + aynı
# apply-defaults.sh ile.
#
# Düğümün config'i Syncthing'in kendi varsayılan yerine ($HOME/Library/
# Application Support/Syncthing) değil, ~/.mortise altına kurulur: bu
# makinede ayrıca bir Syncthing kurulumu varsa ikisi birbirine karışmaz.
#
# FORK NOKTASI: Faz 2'de fork'lanmış kendi binary'mize geçildiğinde
# değişecek yer aşağıdaki "1) Binary" adımıdır. Ayrıntı: docs/fork-notes.md
set -euo pipefail

NODE_HOME="${MORTISE_NODE_HOME:-$HOME/.mortise}"
GUI="${MORTISE_NODE_GUI:-127.0.0.1:8384}"
LABEL="net.mortise.node"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[ "$(uname)" = "Darwin" ] || { echo "bu script macOS içindir" >&2; exit 1; }

# 1) Binary
if ! command -v syncthing > /dev/null 2>&1; then
  echo "==> binary kuruluyor (brew)"
  brew install syncthing
fi
BIN="$(command -v syncthing)"
echo "==> binary : $($BIN --version | cut -d' ' -f1-2)"

# 2) Dizinler
mkdir -p "$NODE_HOME/config" "$NODE_HOME/data" "$NODE_HOME/logs"
echo "==> home   : $NODE_HOME"

# 3) LaunchAgent — login'de açılır, çökerse yeniden başlar
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
echo "==> servis : $LABEL yüklendi (login'de otomatik açılır)"

# 4) API'nin ayağa kalkmasını bekle. İlk denemeler servis açılana kadar
#    başarısız olur; -s ile sessiz tutulup sonuç tek satırda bildiriliyor.
if curl -fs --retry 30 --retry-delay 1 --retry-connrefused --retry-all-errors \
     -o /dev/null "http://$GUI/rest/noauth/health"; then
  echo "==> API    : hazır ($GUI)"
else
  echo "API ayağa kalkmadı. Log: $NODE_HOME/logs/node.err" >&2
  exit 1
fi

# 5) Mortise varsayılanları — hub'dakiyle aynı script.
#    Klasör yolu burada container değil, düğümün kendi data dizini.
MORTISE_CONFIG="$NODE_HOME/config/config.xml" \
MORTISE_API="http://$GUI" \
MORTISE_FOLDER_PATH="$NODE_HOME/data" \
  "$REPO/scripts/apply-defaults.sh"

echo
echo "Düğüm hazır. Device ID:"
"$BIN" device-id --home="$NODE_HOME/config"
echo
echo "GUI: http://$GUI   (hub'ın GUI'si için: ./scripts/tunnel.sh -> 8385)"
