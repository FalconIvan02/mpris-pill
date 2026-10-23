#!/usr/bin/env bash
#
# mpris-pill — instalador
# https://github.com/Falconivan02/mpris-pill
#
# Instalación en una línea:
#   curl -fsSL https://raw.githubusercontent.com/Falconivan02/mpris-pill/v1.0.0/install.sh | bash
#
# Con opciones (van después de "--"):
#   curl -fsSL https://raw.githubusercontent.com/Falconivan02/mpris-pill/v1.0.0/install.sh | bash -s -- --yes
#
# Desde un clon del repositorio (usa los archivos locales, sin descargar nada):
#   git clone https://github.com/Falconivan02/mpris-pill && cd mpris-pill && bash install.sh
#
# Qué toca este script:
#   - ~/.config/quickshell/mpris-pill/     (copia shell.qml y cava.conf)
#   - ~/.config/hypr/autostart.lua|conf  (solo si aceptás; con copia de seguridad)
#   - sudo pacman -S quickshell cava     (solo si faltan Y aceptás)
# No toca nada más.

set -euo pipefail

VERSION="v1.0.1"
REPO="${MPRIS_PILL_REPO:-Falconivan02/mpris-pill}"
REF="${MPRIS_PILL_REF:-$VERSION}"
BASE_URL="${MPRIS_PILL_BASE_URL:-https://raw.githubusercontent.com/$REPO/$REF}"

NAME="mpris-pill"
FILES=(shell.qml cava.conf)
MARK="mpris-pill (instalado por install.sh)"
LINE_LUA='o.launch_on_start("quickshell -c mpris-pill --no-duplicate")'
LINE_CONF='exec-once = quickshell -c mpris-pill --no-duplicate'
# Solo cuenta como "en ejecución" un proceso cuya línea de comandos EMPIECE por quickshell
# (así no confunde, por ejemplo, otra shell que solo mencione esa frase).
PROC_RE='^([^ ]*/)?quickshell -c mpris-pill( |$)'

ASSUME_YES=0
NO_AUTOSTART=0
NO_LAUNCH=0
TMP=""
LOCAL_SRC=""
STAMP="$(date +%Y%m%d-%H%M%S)"

# ───────────── Mensajes ─────────────
if [ -t 1 ]; then
  C_B=$'\033[1m'; C_G=$'\033[32m'; C_Y=$'\033[33m'; C_R=$'\033[31m'; C_N=$'\033[0m'
else
  C_B=""; C_G=""; C_Y=""; C_R=""; C_N=""
fi
info() { printf '%s==>%s %s\n' "$C_B" "$C_N" "$*"; }
ok()   { printf '%s ✓%s %s\n' "$C_G" "$C_N" "$*"; }
warn() { printf '%s !%s %s\n' "$C_Y" "$C_N" "$*" >&2; }
die()  { printf '%s ✗%s %s\n' "$C_R" "$C_N" "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
mpris-pill — instalador

Opciones:
  -y, --yes          No preguntar nada (responde "sí" a todo)
      --no-autostart No tocar la configuración de arranque de Hyprland
      --no-launch    No lanzar el widget al terminar
  -h, --help         Mostrar esta ayuda
EOF
}

# ───────────── Utilidades ─────────────
have_tty() { (: </dev/tty) 2>/dev/null; }

# Pregunta sí/no. Con --yes responde que sí; sin terminal disponible, que no.
# (Leemos de /dev/tty porque con "curl | bash" la entrada estándar es el propio script.)
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

# version_ge A B → verdadero si A >= B
version_ge() {
  [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

is_omarchy() {
  [ -n "${OMARCHY_PATH:-}" ] || [ -d "$CONFIG_HOME/omarchy" ] || command -v omarchy-version >/dev/null 2>&1
}

# ¿Tiene el archivo una línea ACTIVA (no comentada) que lance mpris-pill?
# $1 = archivo, $2 = prefijo de comentario
active_has() {
  grep -v "^[[:space:]]*$2" "$1" 2>/dev/null | grep -q 'quickshell -c mpris-pill'
}

cleanup() {
  [ -n "${TMP:-}" ] && rm -rf "$TMP"
  return 0
}

# ───────────── Pasos ─────────────
preflight() {
  [ "$(id -u)" -eq 0 ] && die "No ejecutes este script como root: instala en tu carpeta personal."

  CONFIG_HOME="$HOME/.config"
  if [ -n "${XDG_CONFIG_HOME:-}" ] && [ "$XDG_CONFIG_HOME" != "$HOME/.config" ]; then
    die "Tenés XDG_CONFIG_HOME=$XDG_CONFIG_HOME. mpris-pill asume ~/.config por ahora; no se instaló nada."
  fi
  DEST="$CONFIG_HOME/quickshell/$NAME"

  command -v curl >/dev/null 2>&1 || [ -n "$LOCAL_SRC" ] || die "Hace falta curl."

  if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    warn "No detecto una sesión de Hyprland en marcha. Se instalará igual, pero solo está probado en Hyprland."
  fi
}

ensure_deps() {
  local missing=()
  command -v quickshell >/dev/null 2>&1 || missing+=(quickshell)
  command -v cava >/dev/null 2>&1 || missing+=(cava)

  if [ ${#missing[@]} -gt 0 ]; then
    warn "Faltan dependencias: ${missing[*]}"
    if ! command -v pacman >/dev/null 2>&1; then
      die "No encontré pacman. Instalá manualmente ${missing[*]} (Quickshell 0.3 o superior) y volvé a ejecutar."
    fi
    info "Comando a ejecutar: sudo pacman -S --needed ${missing[*]}"
    info "(Si tu sistema no está al día, actualizalo antes con 'sudo pacman -Syu'.)"
    if ask "¿Instalarlas ahora?"; then
      if [ "$ASSUME_YES" = 1 ]; then
        sudo pacman -S --needed --noconfirm "${missing[@]}" </dev/null
      else
        # La redirección la hace tu shell (no sudo) y tu usuario puede leer /dev/tty.
        # shellcheck disable=SC2024
        sudo pacman -S --needed "${missing[@]}" </dev/tty
      fi
    else
      die "Instalá ${missing[*]} y volvé a ejecutar este script."
    fi
    command -v quickshell >/dev/null 2>&1 || die "quickshell sigue sin estar disponible."
    command -v cava >/dev/null 2>&1 || die "cava sigue sin estar disponible."
  fi

  local ver
  ver="$(quickshell --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true)"
  if [ -n "$ver" ]; then
    if version_ge "$ver" "0.3.0"; then
      ok "Quickshell $ver y cava disponibles."
    else
      warn "Quickshell $ver detectado; mpris-pill está probado con 0.3.0 o superior y puede fallar."
    fi
  else
    ok "Quickshell y cava disponibles."
  fi
}

fetch_files() {
  TMP="$(mktemp -d)"
  local f
  for f in "${FILES[@]}"; do
    if [ -n "$LOCAL_SRC" ]; then
      cp "$LOCAL_SRC/$f" "$TMP/$f"
    else
      curl -fsSL --retry 3 --connect-timeout 10 "$BASE_URL/$f" -o "$TMP/$f" \
        || die "No pude descargar $BASE_URL/$f"
    fi
    [ -s "$TMP/$f" ] || die "El archivo $f llegó vacío."
  done
  grep -q 'ShellRoot' "$TMP/shell.qml" || die "El shell.qml descargado no parece válido."
}

install_files() {
  mkdir -p "$DEST"
  local f bak
  for f in "${FILES[@]}"; do
    if [ -f "$DEST/$f" ] && ! cmp -s "$TMP/$f" "$DEST/$f"; then
      bak="$DEST/$f.bak-$STAMP"
      cp -p "$DEST/$f" "$bak"
      warn "Ya existía $f con otro contenido (¿personalizado?). Copia guardada en: $bak"
    fi
    install -m 0644 "$TMP/$f" "$DEST/$f"
  done
  ok "Archivos instalados en $DEST"
}

manual_autostart() {
  cat <<EOF

Para que mpris-pill arranque con Hyprland, añadí UNA de estas opciones a tu configuración:

  Omarchy (~/.config/hypr/autostart.lua):
    $LINE_LUA

  Hyprland con archivos .conf:
    $LINE_CONF

  Hyprland con Lua puro (hyprland.lua):
    hl.on("hyprland.start", function()
      hl.exec_cmd("quickshell -c mpris-pill --no-duplicate")
    end)

EOF
}

# append_line ARCHIVO PREFIJO_COMENTARIO LINEA
append_line() {
  local file="$1" cprefix="$2" line="$3"
  cp -p "$file" "$file.bak-$STAMP"
  printf '\n%s %s\n%s\n' "$cprefix" "$MARK" "$line" >>"$file"
  ok "Autostart añadido a $file (copia: $file.bak-$STAMP)"
}

setup_autostart() {
  if [ "$NO_AUTOSTART" = 1 ]; then
    info "Autostart omitido (--no-autostart)."
    return 0
  fi

  local hypr="$CONFIG_HOME/hypr"
  local lua="$hypr/autostart.lua" conf="$hypr/autostart.conf"

  if [ -f "$lua" ]; then
    if active_has "$lua" '--'; then
      ok "El autostart ya estaba configurado en $lua"
      return 0
    fi
    if is_omarchy || grep -q 'launch_on_start' "$lua"; then
      if ask "¿Añadir mpris-pill a $lua para que arranque con Hyprland?"; then
        append_line "$lua" '--' "$LINE_LUA"
      else
        manual_autostart
      fi
      return 0
    fi
  elif [ -f "$conf" ]; then
    if active_has "$conf" '#'; then
      ok "El autostart ya estaba configurado en $conf"
      return 0
    fi
    if ask "¿Añadir mpris-pill a $conf para que arranque con Hyprland?"; then
      append_line "$conf" '#' "$LINE_CONF"
    else
      manual_autostart
    fi
    return 0
  fi

  warn "No encontré un archivo de autostart que sepa modificar con seguridad."
  manual_autostart
}

launch_now() {
  [ "$NO_LAUNCH" = 1 ] && return 0
  if [ -z "${WAYLAND_DISPLAY:-}" ]; then
    warn "No hay una sesión Wayland activa en esta terminal: arrancará en tu próximo inicio de sesión."
    return 0
  fi
  if pgrep -f -- "$PROC_RE" >/dev/null 2>&1; then
    ok "mpris-pill ya estaba en ejecución (Quickshell normalmente recarga solo al cambiar los archivos)."
  else
    if setsid -f quickshell -c "$NAME" --no-duplicate >/dev/null 2>&1 </dev/null; then
      ok "mpris-pill lanzado."
    else
      warn "No pude lanzarlo. Probá a mano: quickshell -c $NAME"
    fi
  fi
}

summary() {
  cat <<EOF

${C_B}Listo.${C_N} Poné música en Spotify: la cápsula aparece abajo al centro.
  • Pasá el ratón por encima para ver título y controles.
  • Clic derecho sobre la cápsula: cambia su color.
  • Para personalizar, editá: $DEST/shell.qml (sección AJUSTES)
  • Si algo falla, lanzalo a mano para ver los errores:  quickshell -c $NAME
  • Para desinstalar:
      curl -fsSL https://raw.githubusercontent.com/$REPO/$REF/uninstall.sh | bash
EOF
}

main() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -y|--yes) ASSUME_YES=1 ;;
      --no-autostart) NO_AUTOSTART=1 ;;
      --no-launch) NO_LAUNCH=1 ;;
      -h|--help) usage; exit 0 ;;
      *) die "Opción desconocida: $1 (probá --help)" ;;
    esac
    shift
  done

  trap cleanup EXIT

  # Si se ejecuta desde un clon del repositorio, usamos los archivos locales.
  local src="${BASH_SOURCE[0]:-}" d
  if [ -z "${MPRIS_PILL_BASE_URL:-}" ] && [ -n "$src" ] && [ -f "$src" ]; then
    d="$(cd "$(dirname "$src")" && pwd)"
    if [ -f "$d/shell.qml" ] && [ -f "$d/cava.conf" ]; then
      LOCAL_SRC="$d"
    fi
  fi

  info "Instalando mpris-pill $VERSION"
  preflight
  ensure_deps
  fetch_files
  install_files
  setup_autostart
  launch_now
  summary
}

# Todo el script se lee completo antes de ejecutar main: así, si la descarga
# se corta a la mitad, no se ejecuta nada a medias.
main "$@"
