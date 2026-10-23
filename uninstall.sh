#!/usr/bin/env bash
#
# mpris-pill — desinstalador
# https://github.com/Falconivan02/mpris-pill
#
#   curl -fsSL https://raw.githubusercontent.com/Falconivan02/mpris-pill/v1.0.0/uninstall.sh | bash
#   (o "bash uninstall.sh" desde un clon del repositorio)
#
# Qué hace:
#   - Cierra mpris-pill si está en ejecución.
#   - Quita las líneas de autostart que añadió install.sh (con copia de seguridad).
#   - Borra ~/.config/quickshell/mpris-pill/
# Qué NO hace: no desinstala quickshell ni cava (podrías usarlos para otras cosas).

set -euo pipefail

NAME="mpris-pill"
PROC_RE='^([^ ]*/)?quickshell -c mpris-pill( |$)'
ASSUME_YES=0
STAMP="$(date +%Y%m%d-%H%M%S)"

if [ -t 1 ]; then
  C_B=$'\033[1m'; C_G=$'\033[32m'; C_Y=$'\033[33m'; C_R=$'\033[31m'; C_N=$'\033[0m'
else
  C_B=""; C_G=""; C_Y=""; C_R=""; C_N=""
fi
info() { printf '%s==>%s %s\n' "$C_B" "$C_N" "$*"; }
ok()   { printf '%s ✓%s %s\n' "$C_G" "$C_N" "$*"; }
warn() { printf '%s !%s %s\n' "$C_Y" "$C_N" "$*" >&2; }
die()  { printf '%s ✗%s %s\n' "$C_R" "$C_N" "$*" >&2; exit 1; }

have_tty() { (: </dev/tty) 2>/dev/null; }

ask() {
  [ "$ASSUME_YES" = 1 ] && return 0
  have_tty || return 1
  local reply
  read -r -p "$1 [S/n] " reply </dev/tty || return 1
  case "${reply:-S}" in
    [sSyY]*) return 0 ;;
    *) return 1 ;;
  esac
}

# Quita de un archivo las líneas que añadió el instalador (con copia previa)
clean_autostart() {
  local file="$1"
  [ -f "$file" ] || return 0
  if grep -q -e 'quickshell -c mpris-pill' -e 'mpris-pill (instalado por install.sh)' "$file"; then
    cp -p "$file" "$file.bak-$STAMP"
    sed -i -e '/mpris-pill (instalado por install.sh)/d' -e '/quickshell -c mpris-pill/d' "$file"
    ok "Autostart quitado de $file (copia: $file.bak-$STAMP)"
  fi
}

main() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -y|--yes) ASSUME_YES=1 ;;
      -h|--help)
        echo "Uso: uninstall.sh [-y|--yes]"
        exit 0
        ;;
      *) die "Opción desconocida: $1" ;;
    esac
    shift
  done

  [ "$(id -u)" -eq 0 ] && die "No ejecutes este script como root."

  local cfg="$HOME/.config"
  local dest="$cfg/quickshell/$NAME"

  info "Desinstalando mpris-pill"

  if pgrep -f -- "$PROC_RE" >/dev/null 2>&1; then
    pkill -f -- "$PROC_RE" || true
    ok "mpris-pill cerrado."
  fi

  clean_autostart "$cfg/hypr/autostart.lua"
  clean_autostart "$cfg/hypr/autostart.conf"

  if [ -d "$dest" ]; then
    if ask "¿Borrar $dest? (incluye tus cambios en shell.qml)"; then
      rm -rf "$dest"
      ok "Carpeta borrada: $dest"
    else
      warn "No se borró $dest."
    fi
  else
    info "No había nada en $dest."
  fi

  cat <<EOF

${C_B}Listo.${C_N} Quickshell y cava siguen instalados. Si querés quitar cava:
  sudo pacman -Rns cava
(Quickshell mejor dejarlo si usás otras configuraciones que lo necesiten.)
EOF
}

main "$@"
