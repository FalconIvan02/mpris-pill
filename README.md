# mpris-pill

Una cápsula de música para **Hyprland**, al estilo de la Dynamic Island de iOS. Aparece abajo al centro cuando suena Spotify: carátula a la izquierda, ecualizador a la derecha. Al pasar el ratón se agranda y muestra título, artista y controles.

<!-- TODO: añadí aquí una captura o un GIF, por ejemplo docs/demo.gif
![mpris-pill](docs/demo.gif)
-->

- **Solo aparece mientras suena música.** En pausa se esconde sola (si tenés el ratón encima, se queda).
- **Compacta:** carátula + ecualizador en tiempo real.
- **Con el ratón encima:** se agranda y aparecen título, artista y los botones anterior, pausa/reproducir y siguiente.
- **Clic derecho:** cambia el color de la cápsula entre una paleta de 5.
- **Sigue el tema de Omarchy:** barras, textos y el color principal de la cápsula cambian solos al cambiar de tema.
- **Liviana:** el ecualizador (`cava`) solo se ejecuta mientras suena música.
- **No reserva espacio:** flota sobre tus ventanas sin empujarlas, y el resto de la ventana deja pasar los clics.

## Requisitos

| Qué | Detalle |
|---|---|
| Compositor | Hyprland (Wayland) |
| [Quickshell](https://quickshell.org) | 0.3.0 o superior |
| [cava](https://github.com/karlstav/cava) | cualquier versión reciente |
| Reproductor | Spotify (app de escritorio, con MPRIS) |

Probado en: CachyOS (base Arch) con Omarchy, Hyprland con configuración en Lua, Quickshell 0.3.0, PipeWire, GPU NVIDIA y Spotify nativo. Otras combinaciones pueden funcionar, pero no están probadas.

## Instalación

### Con una línea

```bash
curl -fsSL https://raw.githubusercontent.com/Falconivan02/mpris-pill/v1.0.0/install.sh | bash
```

El instalador:

1. Comprueba que tengas `quickshell` y `cava`. Si faltan y usás `pacman`, **te pregunta** antes de ejecutar `sudo pacman -S --needed ...`.
2. Copia `shell.qml` y `cava.conf` a `~/.config/quickshell/mpris-pill/`. Si ya existía un archivo distinto, guarda una copia `.bak-FECHA` al lado.
3. Te pregunta si querés que arranque con Hyprland. Si aceptás, añade **una línea** a tu `autostart.lua` (o `autostart.conf`), con copia de seguridad previa.
4. Lanza el widget.

No toca nada más. Es seguro ejecutarlo varias veces: no duplica el autostart ni lanza dos cápsulas.

**Opciones** (se pasan después de `bash -s --`):

```bash
curl -fsSL https://raw.githubusercontent.com/Falconivan02/mpris-pill/v1.0.0/install.sh | bash -s -- --yes
```

| Opción | Efecto |
|---|---|
| `-y`, `--yes` | No pregunta nada: responde "sí" a todo (incluida la instalación de paquetes) |
| `--no-autostart` | No toca tu configuración de arranque |
| `--no-launch` | No lanza el widget al terminar |
| `-h`, `--help` | Muestra la ayuda |

### Revisando antes de ejecutar

Ejecutar un script descargado sin leerlo es una cuestión de confianza. Si preferís mirarlo antes:

```bash
git clone https://github.com/Falconivan02/mpris-pill
cd mpris-pill
less install.sh      # leelo
bash install.sh     # usa los archivos locales, sin descargar nada
```

Los comandos de una línea de este README apuntan a una **versión fija** (`v1.0.0`), así que el contenido no cambia sin que lo notes.

### Arranque automático manual

Si el instalador no reconoce tu configuración, añadí **una** de estas líneas:

```lua
-- Omarchy (~/.config/hypr/autostart.lua)
o.launch_on_start("quickshell -c mpris-pill --no-duplicate")
```

```ini
# Hyprland con archivos .conf
exec-once = quickshell -c mpris-pill --no-duplicate
```

```lua
-- Hyprland con Lua puro (hyprland.lua)
hl.on("hyprland.start", function()
  hl.exec_cmd("quickshell -c mpris-pill --no-duplicate")
end)
```

`--no-duplicate` evita que se abra una segunda cápsula si ya hay una en marcha.

## Uso

- **Poné música en Spotify:** la cápsula sube desde abajo.
- **Pasá el ratón por encima:** se agranda y aparecen los controles.
- **Clic derecho:** siguiente color de la paleta. Al reiniciar el widget vuelve al color del tema.

## Personalización

Todo está en la sección `AJUSTES` al principio de `~/.config/quickshell/mpris-pill/shell.qml`. Quickshell normalmente recarga solo al guardar el archivo.

```qml
readonly property var pillPalette: [
    "theme",    // 0 → color del tema activo de Omarchy (el que arranca)
    "#000000",  // 1 → negro puro
    "#1e1e2e",  // 2
    "#12121b",  // 3
    "#2e3440"   // 4
]
readonly property string themePillKey: "darker_background"
```

- **Colores de la cápsula:** cambiá, añadí o quitá entradas de `pillPalette`. La palabra `"theme"` significa "usar el color del tema". Cuidado: un hexadecimal de 8 dígitos se interpreta como transparencia + color (`#AARRGGBB`).
- **Qué color del tema usa `"theme"`:** `themePillKey` acepta cualquier clave del `colors.toml` de tu tema (`darker_background`, `background`, `accent`...).
- **Cantidad de barras:** `barCount` en `shell.qml` y `bars` en `cava.conf` deben coincidir.
- **Tamaños y animaciones:** busca `width: expanded ? 430 : 300` y las líneas `Behavior on ...` dentro del `Rectangle` llamado `pill`.
- **Otro reproductor:** el filtro está en la propiedad `player`, donde dice `"spotify"`. Cambiá esa palabra por parte del nombre de tu reproductor (por ejemplo `"vlc"`).

Fuera de Omarchy, donde no existe `~/.config/omarchy/current/theme/colors.toml`, el widget usa colores de respaldo (acento beige sobre cápsula negra).

## Desinstalar

```bash
curl -fsSL https://raw.githubusercontent.com/Falconivan02/mpris-pill/v1.0.0/uninstall.sh | bash
```

Cierra el widget, quita la línea de autostart (con copia de seguridad) y borra `~/.config/quickshell/mpris-pill/`. No desinstala `quickshell` ni `cava`, porque podrías usarlos para otras cosas.

## Cómo funciona

```
Spotify ──MPRIS──▶ Quickshell (shell.qml) ◀── cava (cava.conf) ◀── audio (PipeWire)
                        │          ▲
                        │          └── colors.toml del tema de Omarchy
                        ▼
              cápsula (layer-shell, abajo al centro)
```

- **Datos de la canción y controles:** Quickshell los lee por MPRIS, el estándar de control de reproductores.
- **Ecualizador:** `cava` analiza el audio y escribe por salida estándar una línea de números por fotograma; el widget las dibuja como barras.
- **Colores del tema:** se lee `colors.toml` del tema activo. Como `omarchy-theme-set` reemplaza esa carpeta entera, el widget vigila el archivo `current/theme.name`, que se reescribe justo después, y entonces relee los colores.
- **Ventana:** una capa de Wayland sin zona exclusiva, para que no empuje tus ventanas. Solo la cápsula recibe el ratón.

## Solución de problemas

**No aparece la cápsula.**
Lanzalo a mano para ver los errores:
```bash
pkill -f "quickshell -c mpris-pill"; quickshell -c mpris-pill
```
Comprobá también que Spotify esté *reproduciendo* (en pausa, la cápsula se esconde) y que aparezca en `busctl --user list | grep -i mpris`.

**Aparece, pero sin carátula.**
La carátula llega como una dirección `https://` de Spotify, así que hace falta conexión a internet.

**Las barras no se mueven.**
Probá cava por separado: `cava -p ~/.config/quickshell/mpris-pill/cava.conf` debería imprimir líneas de números mientras suena algo. Si `pactl info` no muestra un servidor PulseAudio o PipeWire, cava no tendrá de dónde capturar.

**Queda un proceso `cava` suelto al cerrar.**
`pgrep -a cava` lo muestra y `pkill cava` lo cierra.

**Se abren dos cápsulas.**
Asegurate de lanzarlo con `--no-duplicate`, como en las líneas de arranque de arriba.

## Limitaciones

- Solo reacciona a Spotify (se puede cambiar, ver *Personalización*).
- Requiere Quickshell 0.3.0 o superior.
- El instalador asume `~/.config` y se detiene si definís otro `XDG_CONFIG_HOME`.
- Solo probado en Hyprland. Otros compositores con soporte de layer-shell podrían funcionar, sin garantías.
- La sincronización de colores es específica de Omarchy.

## Licencia

[MIT](LICENSE).
