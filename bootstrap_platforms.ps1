$ErrorActionPreference = "Stop"
flutter --version
flutter create --platforms=android,ios .
flutter pub get
flutter test
Write-Host "CaseCraft platform runners generated and tests completed."
