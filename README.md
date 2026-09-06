<p align="center">
  <img src="resources/glance-icon.png" width="128" height="128" alt="Glance icon" />
</p>

<h1 align="center">Glance</h1>

<p align="center">
  Custom status bar for macOS. Replaces the boring default bar with something actually nice to look at.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14.6%2B-blue" alt="macOS 14.6+" />
  <img src="https://img.shields.io/badge/Swift-5-orange" alt="Swift 5" />
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License" />
</p>

---

<p align="center">
  <img src="resources/Liquid%20Glass.png" width="100%" alt="Glance with Liquid Glass preset" />
</p>

https://github.com/user-attachments/assets/7a3114a6-12dc-42a6-87f0-127b7f67dc6d

## About this fork

This is [ayamdobhal/glance](https://github.com/ayamdobhal/glance), an independently
maintained fork of [azixxxxx/glance](https://github.com/azixxxxx/glance).
The original project provides Glance’s native macOS bar, presets, widgets and
settings. This fork builds on that work with an extensible SwiftUI widget API
and improvements for everyday use with yabai.

### Changes in this fork

- **Native SwiftUI widget bundles:** versioned SDK, bundle discovery, lifecycle
  callbacks, interactive bar views and popups, build tooling and a Counter example.
  Widgets ship separately without rebuilding the app. See the [SDK guide](docs/native-widgets.md).
- **Claude/Codex usage:** available as a separate
  [glance-ai-usage widget](https://github.com/ayamdobhal/glance-ai-usage), with token
  activity, usage limits and reset times. Provider code stays outside Glance.
- **Multiple displays:** a bar on every display, yabai spaces filtered to their
  display, popup placement, display connection handling and display-aware window spacing.
- **Spaces:** empty spaces remain visible, floating app windows are included,
  utility panels are excluded, and each display’s visible space is highlighted.
- **Battery fixes:** health uses the system-reported maximum capacity; the battery
  charge graphic fills correctly at 100%.
- **System accents:** built-in accents follow macOS, including popup icons and
  media/volume sliders. `accent-color` can override the system color independently
  of border and glow colors.
- **Network rates:** optional compact upload/download readings before the network icon.
- **Bar ergonomics:** tighter native widget spacing and no Command-Q shortcut;
  explicit Quit remains available.

Our [dotfiles setup](https://github.com/ayamdobhal/mac-dotfiles/tree/main/glance)
provides the transparent bar theme, widget order and Nix-managed startup/yabai
spacing. These are configuration choices rather than required defaults.

## What is this

Glance is a status bar replacement for macOS. It sits at the top of your screen and shows you the stuff you actually care about: workspaces, current track, volume, Wi-Fi, battery, time. Everything is configurable through a simple TOML file or a Settings GUI.

Built with native Swift and SwiftUI. No Electron, no web views, no bloat.

## Features

- **Liquid Glass UI** with blur, gradient borders, glow, and shadows
- **11 built-in presets** so you can match your setup
- **16 widgets** — spaces, now playing, weather, battery, volume, brightness, bluetooth, clipboard, pomodoro, and more
- **Native macOS Spaces** out of the box (yabai and AeroSpace also supported)
- **Rich popups** for every widget: calendar with events, network speed, battery health, now playing with progress bar
- **4 bar formations**: full, floating, islands, pills
- **Custom script widgets** — run any shell command and display its output in the bar
- **Auto-updates** via Sparkle
- **TOML config** with live reload. Edit, save, see changes instantly
- **Settings GUI** if you don't want to touch config files
- **Global hotkey** (Ctrl+Option+B) to toggle bar visibility
- **Fullscreen auto-hide** — bar fades when apps go fullscreen
- **Window gap management** so maximized windows don't hide behind the bar
- **Launch at Login** via native macOS login items

## Widgets

Custom SwiftUI widgets can be built as separate bundles and enabled without
rebuilding Glance. See the [native widget SDK guide](docs/native-widgets.md) and
the [Counter example](examples/Counter) for interactive bar views and popups.


| Widget | What it shows |
|--------|---------------|
| **Spaces** | Your workspaces with app icons. Click to switch. 5 display modes, 4 highlight styles |
| **Active App** | Name of the frontmost app |
| **Now Playing** | Current track, album art, progress bar, controls (Music & Spotify) |
| **Volume** | Speaker icon, scroll to adjust. Popup: slider + output device |
| **Brightness** | Display brightness, scroll to adjust |
| **Network** | Wi-Fi/Ethernet status. Optional bar upload/download rates: `show-speed = true` under `[widgets.default.network]`. Popup: signal, speed, IP, Tx Rate |
| **Battery** | Charge level. Popup: health %, cycles, temperature |
| **Bluetooth** | Connected devices with battery levels (AirPods, keyboards, mice) |
| **Time** | Customizable date/time. Popup: calendar grid + upcoming events |
| **Weather** | Temperature + condition. Popup: humidity, wind, feels like, 5-day forecast |
| **System Monitor** | CPU % + RAM usage. Popup: usage bars, memory pressure |
| **Disk** | Storage usage with free/total display |
| **Input Language** | Current keyboard layout, zero-polling |
| **Clipboard** | Clipboard history (20 entries), click to paste |
| **Pomodoro** | Focus timer with work/break cycles and notifications |
| **Script** | Run any shell command on an interval. Display output as text |

Plus `spacer` and `divider` for layout.

## Presets

Pick one line in your config and the whole bar changes:

<table>
<tr>
<td align="center"><img src="resources/Liquid%20Glass.png" alt="Liquid Glass" /><br/><b>Liquid Glass</b></td>
<td align="center"><img src="resources/Frosty.png" alt="Frosted" /><br/><b>Frosted</b></td>
</tr>
<tr>
<td align="center"><img src="resources/Tokyo%20Night.png" alt="Tokyo Night" /><br/><b>Tokyo Night</b></td>
<td align="center"><img src="resources/Dracula.png" alt="Dracula" /><br/><b>Dracula</b></td>
</tr>
<tr>
<td align="center"><img src="resources/Nord.png" alt="Nord" /><br/><b>Nord</b></td>
<td align="center"><img src="resources/Catpuccin.png" alt="Catppuccin" /><br/><b>Catppuccin</b></td>
</tr>
<tr>
<td align="center"><img src="resources/Gruvbox.png" alt="Gruvbox" /><br/><b>Gruvbox</b></td>
<td align="center"><img src="resources/Solarized.png" alt="Solarized" /><br/><b>Solarized</b></td>
</tr>
<tr>
<td align="center"><img src="resources/Neon.png" alt="Neon" /><br/><b>Neon</b></td>
<td align="center"><img src="resources/Dark.png" alt="Flat Dark" /><br/><b>Flat Dark</b></td>
</tr>
<tr>
<td align="center"><img src="resources/Minimal.png" alt="Minimal" /><br/><b>Minimal</b></td>
<td></td>
</tr>
</table>

## Settings

No need to edit files if you don't want to. The Settings GUI covers presets, appearance tuning, widget order, and more.

<table>
<tr>
<td><img src="resources/General%20Settings.png" alt="General Settings" /></td>
<td><img src="resources/Widgets%20Settings.png" alt="Widgets Settings" /></td>
</tr>
</table>

### Settings in action

https://github.com/user-attachments/assets/bedb799d-f3ae-43ee-a64c-5f3034a5b422

### Switching presets

https://github.com/user-attachments/assets/66156dbe-6521-41b0-a465-234e8558d4c6

## Installation

Build this fork from source to get the changes above. The original project's
[Homebrew tap](https://github.com/azixxxxx/homebrew-tap) and
[release downloads](https://github.com/azixxxxx/glance/releases) distribute upstream Glance.
For local fork builds, disable upstream automatic updates in Settings to keep
Sparkle from replacing the app with an upstream release.

### Build from source

Requires Xcode 16+ and macOS 14.6+.

```bash
git clone https://github.com/ayamdobhal/glance.git
cd glance

xcodebuild -project Glance.xcodeproj -scheme Glance -configuration Release \
  -derivedDataPath build build \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Sign a separate copy so incremental Xcode builds remain intact.
glance_install_dir=$(mktemp -d)
ditto build/Build/Products/Release/Glance.app "$glance_install_dir/Glance.app"
codesign --force --deep --sign - "$glance_install_dir/Glance.app"
open "$glance_install_dir/Glance.app"
```

## Multiple displays

Glance creates a bar on every connected display. With yabai, each bar shows only
that display's spaces, including empty spaces and floating app windows. Popups
follow the originating display, and display connect/disconnect events update the
bars. Native widgets receive one instance per display.

Display mapping/geometry checks are available with `sh scripts/test-displays.sh`.

## Configuration

Config loads from `~/.glance-config.toml` first, then `~/.config/glance/config.toml`.
Changes reload automatically. See the [dotfiles example](https://github.com/ayamdobhal/mac-dotfiles/blob/main/glance/config.toml).

```toml
theme = "dark"

# Switch preset and the whole look changes
preset = "liquid-glass"

# Or tweak individual values
# [appearance]
# roundness = 50          # 0 = square, 50 = capsule
# border-width = 1.0
# fill-opacity = 0.04
# foreground-color = "#ffffff"
# accent-color = "system" # Default: macOS accent; also accepts "#rrggbb"

[widgets]
displayed = [
    "default.spaces",
    "divider",
    "default.activeapp",
    "default.nowplaying",
    "spacer",
    "default.weather",
    "default.systemmonitor",
    "default.disk",
    "default.volume",
    "default.network",
    "default.inputlanguage",
    "default.brightness",
    "default.clipboard",
    "default.bluetooth",
    "divider",
    "default.time",
]

# Custom script widget — run any command, show output in bar
# [widgets.script.vpn]
# command = "scutil --ncs | grep -q Connected && echo '🟢 VPN' || echo '🔴 VPN'"
# interval = 10

[widgets.default.time]
format = "E d MMM, H:mm"
calendar.format = "H:mm"
calendar.show-events = true

[widgets.default.battery]
show-percentage = true

[widgets.default.spaces]
space.show-key = true
window.show-title = true
```

### Available presets

`liquid-glass`, `frosted`, `flat-dark`, `minimal`, `neon`, `tokyo-night`, `dracula`, `gruvbox`, `nord`, `catppuccin`, `solarized`

### Date format

Uses ICU patterns: `E d MMM, H:mm` gives you `Thu 6 Mar, 17:14`. See [ICU Date Format Patterns](https://unicode-org.github.io/icu/userguide/format_parse/datetime/) for all options.

### Window managers

Works with native macOS Spaces by default. Also supports:

- **[yabai](https://github.com/koekeishiya/yabai)** via `yabai.path = "/opt/homebrew/bin/yabai"`
- **[AeroSpace](https://github.com/nikitabobko/AeroSpace)** via `aerospace.path = "/opt/homebrew/bin/aerospace"`

## Permissions

Glance asks for a few permissions on first launch:

| Permission | Why |
|------------|-----|
| **Accessibility** | So maximized windows leave a gap for the bar instead of hiding behind it |
| **Automation (Apple Events)** | To control Music and Spotify for the Now Playing widget |
| **Calendar** | To show upcoming events in the calendar popup |
| **Location** | To display Wi-Fi network name and local weather (falls back to IP geolocation if denied) |

All permissions are optional. The app works without them, you just lose the specific features.

## Requirements

- macOS 14.6 (Sonoma) or later
- Apple Silicon or Intel Mac

## Credits

This fork builds on [Glance by azixxxxx](https://github.com/azixxxxx/glance).
The upstream Glance project started as a fork of [Barik](https://github.com/mocki-toki/barik) by Simon Butenko. Since then, it has diverged into a heavily updated project with native macOS Spaces support, a Settings GUI, expanded widgets, presets, Sparkle updates, live config reload, and ongoing improvements.

## License

[MIT](LICENSE)
