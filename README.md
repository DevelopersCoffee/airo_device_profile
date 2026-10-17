# airo_device_profile

[![pub package](https://img.shields.io/pub/v/airo_device_profile.svg)](https://pub.dev/packages/airo_device_profile)
[![CI](https://github.com/DevelopersCoffee/airo_device_profile/actions/workflows/ci.yml/badge.svg)](https://github.com/DevelopersCoffee/airo_device_profile/actions)
[![Publisher](https://img.shields.io/badge/publisher-developerscoffee.com-blue)](https://pub.dev/publishers/developerscoffee.com/packages)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Runtime device profile, hardware capability signals, memory budget models, and legacy tier classification for Flutter applications across mobile, TV, desktop, and embedded hardware.

Part of the **DevelopersCoffee** open-source ecosystem.

---

## Features

- **Device Capability Signals**: Inspect API level, RAM, GPU class, available media decoders, thermal/memory pressure, and remote input modes.
- **Support Tier Classification**: Automatically classify devices into `fullySupported`, `legacyOptimized`, `experimental`, or `unsupported`.
- **Memory Budget Enforcement**: Model and monitor memory budgets for low-spec TV dongles and legacy receivers.
- **Region Resolution**: Geo-IP region resolution contracts with caching policies for streaming localization.

---

## Usage

```dart
import 'package:airo_device_profile/airo_device_profile.dart';

void main() {
  final signals = AiroRuntimeDeviceSignals(
    signalId: 'sig-123',
    platformCategory: AiroNodePlatformCategory.androidTv,
    apiLevel: 28,
    memoryMb: 1536,
    freeStorageMb: 4096,
    gpuClass: AiroRuntimeGpuClass.standard,
    decoderCount: 4,
    supportedCodecs: const {MediaCodecCapability.h264, MediaCodecCapability.aac},
    remoteInputs: const {AiroRuntimeRemoteInput.dpad, AiroRuntimeRemoteInput.mediaKeys},
    networkClass: AiroRuntimeNetworkClass.stableWifi,
  );

  final policy = AiroRuntimeDeviceProfilePolicy();
  final profile = policy.evaluate(signals: signals, now: DateTime.now());

  print('Support Tier: ${profile.supportTier}');
  print('Is Legacy Receiver Mode Recommended: ${profile.legacyReceiverModeRecommended}');
}
```

---

## Android runtime profiler

Since 1.1.0 the package is a Flutter plugin with an Android implementation. It
requests **no permissions** and makes **no network calls**. Supported on API 24 to 36.

```dart
import 'package:airo_device_profile/airo_device_profile.dart';

// Full profile, classified by AiroRuntimeDeviceProfilePolicy.
final profile = await AiroAndroidRuntimeDeviceProfiler().profile(now: DateTime.now());

// Just the numbers needed to decide whether an on-device model fits.
final fit = await quickDeviceFit();
if (fit.memoryMb >= minMemoryMb && fit.freeStorageMb * 1024 * 1024 > sizeBytes + margin) {
  // offer the download
}
```

On non-Android platforms, or if the plugin is unavailable, `profile()` returns the
same result as `AiroNoOpRuntimeDeviceProfiler` (`profiler_unavailable`) and
`quickDeviceFit()` returns zeros. Neither throws.

### Which fields are real

| Field | Source | Real? |
|---|---|---|
| `apiLevel` | `Build.VERSION.SDK_INT` | Yes |
| `memoryMb` | `ActivityManager.MemoryInfo.totalMem` | Yes |
| `freeStorageMb` | `StatFs(context.filesDir).availableBytes` (app-private volume) | Yes |
| `memoryPressure` | `MemoryInfo.lowMemory` → high; `availMem < threshold × 2` → elevated | Yes |
| `storagePressure` | free storage below policy `legacyFreeStorageMb` → high, below `fullFreeStorageMb` → elevated | Yes |
| `thermalPressure` | `PowerManager.currentThermalStatus`: 0–1 normal, 2 elevated, 3 high, ≥4 critical. API < 29: normal | Yes (API 29+) |
| `platformCategory` | `UiModeManager` TV → `androidTv`; phone and tablet (`smallestScreenWidthDp ≥ 600`) → `androidMobile` | Yes |
| `securityPatchAgeDays` | `Build.VERSION.SECURITY_PATCH` vs `now`; 0 if missing | Yes |
| `decoderCount`, `supportedCodecs` | `MediaCodecList` video decoders and decoder MIME types (h264, aac, hevc, av1, dolby_vision) | Best effort. `hls` / `mpeg_ts` are containers and never reported, so adjust the policy's `baselineCodecs` if you rely on them |
| `remoteInputs` | `dpad` when `Configuration.navigation == NAVIGATION_DPAD` | Best effort (D-pad only) |
| `hasSecureStorage` | `true` when API ≥ 23 (Android Keystore) | Derived |
| `gpuClass` | Not measured. Default `unknown`, override with the `gpuClass` constructor argument | Default |
| `networkClass` | Not measured (would need `ACCESS_NETWORK_STATE`). Default `stableWifi`, override with `networkClass` | Default |
| `decoderFailureCount` | Not measured. `0` | Default |

The default `AiroRuntimeDeviceProfilePolicy` is tuned for TV receivers (it requires a
D-pad and HLS), so a phone usually comes out `unsupported` for that policy. Pass your own
policy, or read `profile.signals` / `quickDeviceFit()` directly for phone-side checks.

The raw-map mapping (`airoAndroidSignalsFromMap` and the `airoAndroid*Pressure` helpers)
is pure Dart and can be tested without a device.

### Example

`example/` prints the profile. It has no platform folders checked in; run
`flutter create --platforms=android .` inside `example/` once, then `flutter run`.

---

## Maintainers

Maintained with ❤️ by **[DevelopersCoffee](https://developerscoffee.com)**.
