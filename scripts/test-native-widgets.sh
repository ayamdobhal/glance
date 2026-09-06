#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_dir=$(mktemp -d /tmp/glance-widget-tests.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT
python3 "$repo_dir/scripts/build-widget.py" "$repo_dir/examples/Counter" --output "$test_dir"
xcrun swiftc -parse-as-library \
  "$repo_dir/Glance/Widgets/Native/GlanceWidgetSDK.swift" \
  "$repo_dir/Glance/Widgets/Native/NativeWidgetBundle.swift" \
  "$repo_dir/tests/NativeWidgetSmoke.swift" \
  -o "$test_dir/smoke"
"$test_dir/smoke" "$test_dir/counter.glancewidget"
