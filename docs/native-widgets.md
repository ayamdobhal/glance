# Native SwiftUI widgets (API v1)

Build a widget once and load it into Glance without rebuilding the bar. A widget
owns its SwiftUI views, state, data fetching, and interactions; Glance places its
bar view, presents its popup, and supplies configuration and theme colors.

This is an initial native extension API. Widgets are executable code running
inside Glance with its permissions. A broken widget can crash or stall Glance.
Only enable bundles you trust. Installation alone does not execute a widget:
Glance reads its manifest for Settings and loads code only when it is enabled.

## Try the example

From this checkout, with Xcode selected (or `DEVELOPER_DIR` set):

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
python3 scripts/build-widget.py examples/Counter --output ~/.config/glance/widgets
```

Open Settings → Widgets → Refresh Widgets and add **Counter Demo**, or add
`"native.counter"` to the existing `[widgets].displayed` array. Place it on either
side of your existing spacer to keep the center free on a MacBook with a notch.

```toml
[widgets.native.counter]
title = "My counter"
```

Click the counter to open its popup. Its buttons, toggle, progress bar, and timer
are SwiftUI code in the separate bundle. Theme and TOML changes are applied live.
Remove it from the displayed array or Settings to stop its timer.

For a bundle outside the default folder, configure a path explicitly:

```toml
[widgets.native.mycounter]
bundle = "~/personal/widgets/counter.glancewidget"
title = "Another counter"
```

Use distinct configured IDs for distinct instances. A bundle can back multiple
instances; each gets its own object, views, config, and data directory.

## Create a widget

Copy `examples/Counter` to your own project and change its `widget.json`:

```json
{
  "id": "mywidget",
  "name": "My Widget",
  "version": "1.0.0",
  "principalClass": "MyWidget",
  "barWidth": 100,
  "popupWidth": 300,
  "popupHeight": 240
}
```

The build helper compiles your Swift files with `GlanceWidgetSDK.swift`, produces
a `.glancewidget` bundle, and ad-hoc signs it. It builds for the current Mac's
architecture and macOS 14.6+. Distribute a matching architecture or build each
architecture separately. No paid signing certificate is needed for local builds.
Signed/hardened distribution of a host that loads third-party code needs a
separate signing/library-validation design; this version targets local builds.

Implement `GlanceWidgetExtension` on an `NSObject` subclass. Return an
`NSHostingView(rootView: ...)` from each view factory. The counter example is a
complete implementation. Put optional images/assets in `Resources/`; the helper
copies this directory into the bundle. Resolve assets using the supplied bundle
URL, not `Bundle.main` (which is Glance).

The public boundary is an explicitly versioned Objective-C protocol using
Foundation/AppKit types. Widget authors can use SwiftUI internally without
linking against Glance's internal types or rebuilding Glance for each widget.

| Method | Contract |
| --- | --- |
| `init()` | Create an instance; defer work until `start`. |
| `start(with:)` | Called once per active instance, before its views are created. Start observers/tasks here. |
| `makeBarView()` | Return the instance's bar view. Its width comes from the manifest. |
| `makePopupView()` | Return a separate popup view, or `nil` for no popup. Created lazily and reused. |
| `update(with:)` | Apply changed config/theme without restarting the widget. |
| `stop()` | Cancel tasks, invalidate timers, and remove observers when disabled or Glance quits. |

All calls occur on the main thread. Keep them fast; use asynchronous work for
network calls and expensive computation. Own a shared observable model for bar
and popup state. Do not return the same NSView for both: a view has one parent.

To request a popup from any button in your bar view, post this on the main thread:

```swift
NotificationCenter.default.post(name: glanceWidgetOpenPopup, object: self)
```

Here `self` is the extension instance, not the SwiftUI view. Pass a callback to
your SwiftUI view, as in the example. Glance anchors the popup to the widget and
uses its normal popup styling and dismissal. It does not intercept your bar's
clicks, so sliders, menus, and buttons can define their own behavior.

## Context dictionary

| Key | Value |
| --- | --- |
| `id` | Configured instance ID, such as `native.counter`. |
| `config` | Widget TOML values converted to Foundation strings, numbers, arrays, and dictionaries. |
| `foregroundColor`, `accentColor` | `NSColor`; convert with `Color(nsColor:)`. |
| `barHeight` | Available widget height in points. |
| `bundleURL` | `NSURL` for the widget bundle and its resources. |
| `dataDirectoryURL` | `NSURL` for a persistent, per-instance directory in Application Support. |

Use Keychain for secrets rather than TOML. Network access and permissions are
the widget's responsibility; Glance does not provide credential handling or a
sandbox per widget.

## Reloading, errors, and compatibility

Config/theme changes update live. **Restart Glance after rebuilding a loaded
widget.** Swift/Objective-C classes cannot safely be unloaded and replaced in
the same process. Rebuilding changes neither Glance nor other installed widgets.
If you rename the Swift module or class, restart as well.

The loader validates API version, identifier, and dimensions before loading code.
It shows an error icon with a tooltip for invalid/missing bundles or entry points.
Settings scans manifests only. Version 1 limits bar widths to 20–600pt and popup
sizes to 120–900pt wide and 60–900pt high. Popup dimensions are fixed for an
instance; put a `ScrollView` inside for larger content. Fit bar widths to your
screen: automatic notch-aware overflow layout is not part of this API.

Existing built-in and `script.*` widgets are unchanged. No custom usage/weather
providers are compiled into Glance by this extension work.

## Validation

```sh
sh scripts/test-native-widgets.sh
```

The smoke check builds the example independently, loads it through the same v1
boundary as Glance, creates both views, exercises update/start/stop and separate
instances, and rejects unsupported versions, invalid IDs, and invalid sizes.

## Multiple displays

Each display gets its own bar and native widget instance. The context includes
`displayID` (NSNumber, a Core Graphics display ID). Popups open on the instance's
display. Removing a display stops its instances; adding one creates new instances.
The data directory remains shared by widget ID, so use atomic writes and
coordinate shared state or polling when needed.
