#!/usr/bin/env bash
set -euo pipefail
flutter --version
flutter create --platforms=android,ios .
flutter pub get
flutter test
printf '\nCaseCraft platform runners generated and tests completed.\n'
