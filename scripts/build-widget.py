#!/usr/bin/env python3
"""Build one SwiftUI widget without rebuilding Glance (stdlib only)."""
import argparse
import json
from pathlib import Path
import platform
import plistlib
import re
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="directory containing widget.json and Swift sources")
    parser.add_argument("--output", type=Path, default=Path("build/widgets"))
    args = parser.parse_args()
    source = args.source.expanduser().resolve()
    metadata = json.loads((source / "widget.json").read_text())
    identifier = metadata["id"]
    if not re.fullmatch(r"[a-zA-Z0-9_-]+", identifier):
        parser.error("id must contain only letters, digits, underscores, or hyphens")
    principal = metadata["principalClass"]
    if not re.fullmatch(r"[a-zA-Z_][a-zA-Z0-9_]*", principal):
        parser.error("principalClass must be a Swift class name")
    for key, lower, upper in [("barWidth", 20, 600), ("popupWidth", 120, 900), ("popupHeight", 60, 900)]:
        if key in metadata:
            value = metadata[key]
            if isinstance(value, bool) or not isinstance(value, (int, float)) or not lower <= value <= upper:
                parser.error(f"{key} must be a number between {lower} and {upper}")
    sources = sorted(source.rglob("*.swift"))
    if not sources:
        parser.error("no Swift sources found")
    module = "GlanceWidget_" + identifier.replace("-", "_")
    output = args.output.expanduser().resolve()
    output.mkdir(parents=True, exist_ok=True)
    destination = output / (identifier + ".glancewidget")
    sdk = Path(__file__).resolve().parents[1] / "Glance/Widgets/Native/GlanceWidgetSDK.swift"
    with tempfile.TemporaryDirectory(prefix=".widget-build-", dir=output) as temporary:
        bundle = Path(temporary) / destination.name
        executable_dir = bundle / "Contents/MacOS"
        executable_dir.mkdir(parents=True)
        executable = executable_dir / module
        arch = "arm64" if platform.machine() == "arm64" else "x86_64"
        subprocess.run([
            "xcrun", "swiftc", "-emit-library", "-parse-as-library", "-O",
            "-module-name", module, "-target", arch + "-apple-macosx14.6",
            "-framework", "AppKit", "-framework", "SwiftUI",
            str(sdk), *map(str, sources), "-o", str(executable),
        ], check=True)
        info = {
            "CFBundleIdentifier": "local.glance.widget." + identifier.replace("_", "-"),
            "CFBundleDisplayName": metadata.get("name", identifier),
            "CFBundleVersion": metadata.get("version", "1.0.0"),
            "CFBundlePackageType": "BNDL",
            "CFBundleExecutable": module,
            "NSPrincipalClass": module + "." + principal,
            "GlanceWidgetAPIVersion": 1,
            "GlanceWidgetIdentifier": identifier,
            "GlanceWidgetBarWidth": metadata.get("barWidth", 80),
            "GlanceWidgetPopupWidth": metadata.get("popupWidth", 300),
            "GlanceWidgetPopupHeight": metadata.get("popupHeight", 240),
        }
        with (bundle / "Contents/Info.plist").open("wb") as file:
            plistlib.dump(info, file)
        resources = source / "Resources"
        if resources.is_dir():
            shutil.copytree(resources, bundle / "Contents/Resources")
        subprocess.run(["codesign", "--force", "--sign", "-", str(bundle)], check=True)
        # Replace the whole bundle only after compilation and signing succeeded.
        backup = Path(temporary) / "previous.glancewidget"
        if destination.exists():
            destination.rename(backup)
        try:
            bundle.rename(destination)
        except OSError:
            if backup.exists():
                backup.rename(destination)
            raise
    print(destination)
    print("Enable native." + identifier + " in Glance. Restart Glance after rebuilding loaded code.")


if __name__ == "__main__":
    main()
