# Platform packaging notes

The application source is complete. Flutter's generated `android/` and `ios/` runners are intentionally not duplicated here because Flutter 3.47 generates current platform boilerplate more safely than a hand-copied runner.

From the root of this folder:

```bash
flutter create --platforms=android,ios .
flutter pub get
flutter test
flutter run
```

No application source edits are required after that.

For Play Store / App Store release, use your normal signing certificates and store account metadata in the platform build environment. Those credentials cannot be embedded in a portable source archive.
