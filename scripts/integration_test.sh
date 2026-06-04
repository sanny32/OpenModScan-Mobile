#!/usr/bin/env bash
#
# Runs the integration test suite with the demo fixtures enabled.
#
# The demo scenarios (app_smoke_test.dart, register_write_test.dart) assert on
# the bundled demo data, which is only seeded when OMODSCAN_DEMO_DATA=true. The
# seeded scenarios (device_crud_test.dart, settings_test.dart) own their state
# and pass with or without the flag, so running the whole suite with the flag is
# the simplest reliable entry point.
#
# Requires a connected device or running emulator/simulator. Pass extra args
# straight through, e.g.:
#   scripts/integration_test.sh -d emulator-5554
#   scripts/integration_test.sh integration_test/settings_test.dart
set -euo pipefail

cd "$(dirname "$0")/.."

exec flutter test integration_test \
  --dart-define=OMODSCAN_DEMO_DATA=true \
  "$@"
