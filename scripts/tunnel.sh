#!/usr/bin/env bash
# Mortise hub GUI'sine SSH tüneli açar.
#
# Hub'ın GUI'si 127.0.0.1:8384'e bağlı ve Caddy'ye hiç bağlanmıyor;
# dışarıdan erişimin tek yolu bu tünel.
set -euo pipefail

HOST="${MORTISE_SSH_HOST:-vds}"
# Yerel port 8384 DEĞİL: bu makine de bir Mortise düğümü ve kendi arayüzü
# 8384'ü tutuyor. 8385'e bağlayıp çakışmayı önlüyoruz.
LOCAL_PORT="${MORTISE_GUI_PORT:-8385}"

echo "Hub GUI  →  http://127.0.0.1:${LOCAL_PORT}"
echo "Kapatmak için Ctrl-C."
exec ssh -N -L "${LOCAL_PORT}:127.0.0.1:8384" "$HOST"
