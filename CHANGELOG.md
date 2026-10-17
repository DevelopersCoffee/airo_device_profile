## 1.1.0

- Package is now a Flutter plugin with an Android implementation (Kotlin, API 24 to 36, no permissions, no network calls).
- Add `AiroAndroidRuntimeDeviceProfiler`, which reads API level, total RAM, free app-private storage, memory/storage/thermal pressure, platform category, security patch level and decoder info over the `airo_device_profile` method channel and classifies them with `AiroRuntimeDeviceProfilePolicy`. Falls back to the no-op profile on other platforms or on plugin errors.
- Add `quickDeviceFit()` returning `({int memoryMb, int freeStorageMb})`.
- Add pure-Dart mapper `airoAndroidSignalsFromMap` and pressure helpers.
- Add example app that prints the profile.
- Fix the `evaluate` call in the README usage sample.

## 1.0.0

- Initial release of `airo_device_profile`.
- Standalone hardware signals evaluation, support tier classification, memory budget enforcement, and region resolution.
