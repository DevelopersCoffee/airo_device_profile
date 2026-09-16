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
  final profile = policy.evaluate(signals, capturedAt: DateTime.now());

  print('Support Tier: ${profile.supportTier}');
  print('Is Legacy Receiver Mode Recommended: ${profile.legacyReceiverModeRecommended}');
}
```

---

## Maintainers

Maintained with ❤️ by **[DevelopersCoffee](https://developerscoffee.com)**.
