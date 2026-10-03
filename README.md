# RedmiBudsBar

A macOS menu bar app for Xiaomi **REDMI Buds** earbuds. It shows battery levels (left, right, case), switches
the noise mode, and exposes the settings your model supports: equalizer presets, custom equalizer curves,
gestures, find my earbuds and more. It lives only in the menu bar (no Dock icon).

![Screenshot](docs/screenshot.png)

<!-- Screenshot placeholder: add docs/screenshot.png -->

## Supported models

Capabilities per model are ported from [Gadgetbridge](https://codeberg.org/Freeyourgadget/Gadgetbridge)'s
REDMI Buds support. The app only shows the controls a model supports. Unknown "Redmi Buds ..." names fall back
to a minimal set (battery and noise mode).

| Model | Status |
| --- | --- |
| REDMI Buds 8 | Tested on hardware |
| REDMI Buds 8 Active | Untested (protocol shared with Gadgetbridge) |
| Redmi Buds 6 Pro | Untested (protocol shared with Gadgetbridge) |
| Redmi Buds 6 | Untested (protocol shared with Gadgetbridge) |
| Redmi Buds 6 Active | Untested (protocol shared with Gadgetbridge) |
| Redmi Buds 6 Lite | Untested (protocol shared with Gadgetbridge) |
| Redmi Buds 5 Pro | Untested (protocol shared with Gadgetbridge) |
| Redmi Buds 4 Active | Untested (protocol shared with Gadgetbridge) |
| Redmi Buds 3 Pro | Untested (protocol shared with Gadgetbridge) |
| Other "Redmi Buds ..." | Generic fallback, untested |

REDMI Buds 8 is modelled as the Buds 8 Active capability set plus noise control, which was confirmed on hardware.
If you test another model, please open an issue with the result.

## Features

- Battery rings for left, right and case, with a charging indicator
- Noise mode (Off / Noise cancelling / Transparency) and level, where the model supports it
- Equalizer: the model's firmware presets, plus app-defined custom curves (Bass Boost+, ASMR, Vocal clarity,
  Night) on models with a custom equalizer
- Find my earbuds (left / right), wearing detection and other toggles the earbuds report
- Gesture configuration (tap actions, long-press cycle)
- English / Spanish / System language, switchable live
- Optional low battery notification (below 15%)
- Launch at login (enabled on first run)
- A device picker in Settings when several REDMI Buds are paired

## Requirements

- macOS 14 or later, Apple Silicon or Intel (releases are universal binaries)
- The earbuds must be paired with the Mac **and connected** to it

## Install from Releases

1. Download `RedmiBudsBar-<version>.zip` from the Releases page and unzip it.
2. Move `RedmiBudsBar.app` to `/Applications`.
3. The app is ad-hoc signed, not notarized, so Gatekeeper blocks the first launch. Either right-click the app
   and choose **Open**, or run:

   ```sh
   xattr -dr com.apple.quarantine /Applications/RedmiBudsBar.app
   ```
4. Allow Bluetooth access when macOS asks.

## Build from source

Requires Xcode / the Swift 6 toolchain.

```sh
swift build
swift test
./scripts/build-app.sh          # universal app in build/, installed to ~/Applications
./scripts/package-release.sh    # dist/RedmiBudsBar-<version>.zip
```

The version comes from the `VERSION` file. `build-app.sh` writes it into `Info.plist`.

## How it works

- The earbuds expose a control channel as an RFCOMM service named **"miwear"** (custom UUID
  `df21fe2c-2515-4fdb-8886-f12c4d67927c`). The app finds the channel through SDP and falls back to channel 28.
- Frames look like `FE DC BA | type | opcode | length (2 bytes, big endian) | [status] | seq | payload | EF`.
  Types: `C4` phone request, `04` response, `C0` earbuds request, `C7` earbuds notification. Several frames can
  arrive in one read, so the decoder is a streaming parser.
- On connect the phone and the earbuds authenticate each other with a challenge/response based on a SAFER+
  variant (opcode `0x50`/`0x51`). The app then requests device info, run info and configuration.
- `Sources/BudsProtocol` is pure Swift (frame codec, authentication, parsers, command builders, model
  capabilities). `Sources/RedmiBudsBar` contains the IOBluetooth transport, view model and SwiftUI views.
  Tests use frames captured from a real REDMI Buds 8 as fixtures.

## Troubleshooting

- **Nothing happens / "Disconnected":** the earbuds must be connected to the Mac (for example as the audio
  output). Use the refresh button in the panel to reconnect.
- **Bluetooth permission:** if you denied it, enable RedmiBudsBar under System Settings > Privacy & Security >
  Bluetooth, then relaunch.
- **Logs:**

  ```sh
  log stream --predicate 'subsystem == "io.github.redmibudsbar.RedmiBudsBar"' --level debug
  ```

  Frames the app does not understand are logged as hex; please include them in bug reports.

## Why there is no iOS version

The control channel is classic Bluetooth RFCOMM. On iOS, third-party apps can only use RFCOMM with accessories
that are part of Apple's MFi program, so this protocol is not reachable from an iOS app.

## Credits and license

The protocol implementation is a port of the REDMI Buds support in
[Gadgetbridge](https://codeberg.org/Freeyourgadget/Gadgetbridge) (Copyright (C) 2024 Jonathan Gobbo and the
Gadgetbridge contributors). Gadgetbridge is licensed under the GNU Affero General Public License v3.0, so this
project is released under **AGPL-3.0-or-later**. See [LICENSE](LICENSE).

## Disclaimer

This is an unofficial community project. It is not affiliated with, endorsed by or sponsored by Xiaomi.
REDMI, Xiaomi and related names are trademarks of their respective owners. Use at your own risk.

## Español

RedmiBudsBar es una app de la barra de menús de macOS para auriculares Xiaomi **REDMI Buds**. Muestra la
batería (izquierdo, derecho y estuche), cambia el modo de ruido y permite ajustar el ecualizador, los gestos y
la función de buscar auriculares, según lo que soporte cada modelo. Solo se ha probado en dispositivos reales
con REDMI Buds 8; los demás modelos usan el mismo protocolo que Gadgetbridge pero no se han probado.

- **Requisitos:** macOS 14 o superior (Apple Silicon o Intel); los auriculares deben estar vinculados y
  conectados al Mac.
- **Instalación:** descarga el `.zip` desde Releases, muévelo a `/Applications` y, como la app tiene firma
  ad hoc, abre con clic derecho > **Abrir** o ejecuta
  `xattr -dr com.apple.quarantine /Applications/RedmiBudsBar.app`.
- **Idioma:** English, Español o el del sistema, desde Ajustes dentro del panel.
- **Licencia:** AGPL-3.0-or-later. Proyecto no oficial, sin relación con Xiaomi.
