#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_dir=$(mktemp -d /tmp/glance-display-tests.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT
xcrun swiftc -parse-as-library \
  "$repo_dir/Glance/Utils/BarDisplay.swift" \
  "$repo_dir/Glance/Widgets/Spaces/Yabai/YabaiModels.swift" \
  "$repo_dir/Glance/Widgets/Spaces/Yabai/YabaiProvider.swift" \
  "$repo_dir/tests/DisplaySmoke.swift" -o "$test_dir/smoke"
"$test_dir/smoke"
