import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'android_runtime_signals_mapper.dart';
import 'runtime_device_profile_models.dart';

/// Method channel used by the Android plugin (`AiroDeviceProfilePlugin`).
const MethodChannel kAiroDeviceProfileChannel = MethodChannel(
  'airo_device_profile',
);

/// Device fit numbers for deciding whether an on-device model can be offered.
typedef AiroQuickDeviceFit = ({int memoryMb, int freeStorageMb});

/// [AiroRuntimeDeviceProfiler] backed by the Android plugin.
///
/// Reads real signals over the `airo_device_profile` method channel, maps them
/// with [airoAndroidSignalsFromMap] and classifies them with [policy], exactly
/// like [AiroFakeRuntimeDeviceProfiler] does with fixed signals.
///
/// On non-Android platforms, or when the plugin is missing or fails, it falls
/// back to [fallback] (by default [AiroNoOpRuntimeDeviceProfiler]) instead of
/// throwing.
class AiroAndroidRuntimeDeviceProfiler implements AiroRuntimeDeviceProfiler {
  AiroAndroidRuntimeDeviceProfiler({
    MethodChannel? channel,
    AiroRuntimeDeviceProfilePolicy? policy,
    this.fallback = const AiroNoOpRuntimeDeviceProfiler(),
    this.gpuClass = AiroRuntimeGpuClass.unknown,
    this.networkClass = AiroRuntimeNetworkClass.stableWifi,
    bool Function()? isAndroid,
  }) : channel = channel ?? kAiroDeviceProfileChannel,
       policy = policy ?? AiroRuntimeDeviceProfilePolicy(),
       _isAndroid = isAndroid ?? _defaultIsAndroid;

  final MethodChannel channel;
  final AiroRuntimeDeviceProfilePolicy policy;
  final AiroRuntimeDeviceProfiler fallback;

  /// Used for `gpuClass`, which has no permission-free Android source.
  final AiroRuntimeGpuClass gpuClass;

  /// Used for `networkClass`, which is not measured (no network permission).
  final AiroRuntimeNetworkClass networkClass;

  final bool Function() _isAndroid;

  static bool _defaultIsAndroid() =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<AiroRuntimeDeviceProfile> profile({required DateTime now}) async {
    final signals = await readSignals(now: now);
    if (signals == null) return fallback.profile(now: now);
    return policy.evaluate(signals: signals, now: now);
  }

  /// Reads and maps the device signals, or returns `null` when they are not
  /// available (non-Android platform, missing plugin, platform error).
  Future<AiroRuntimeDeviceSignals?> readSignals({required DateTime now}) async {
    final raw = await _readRaw();
    if (raw == null) return null;
    return airoAndroidSignalsFromMap(
      raw,
      now: now,
      policy: policy,
      gpuClass: gpuClass,
      networkClass: networkClass,
    );
  }

  /// Total RAM and free app-private storage in MB, without building a full
  /// profile. Returns zeros when the signals are unavailable, so callers
  /// treat the device as too small rather than crash.
  Future<AiroQuickDeviceFit> quickDeviceFit() async {
    final raw = await _readRaw();
    if (raw == null) return (memoryMb: 0, freeStorageMb: 0);
    final signals = airoAndroidSignalsFromMap(
      raw,
      now: DateTime.now(),
      policy: policy,
    );
    return (memoryMb: signals.memoryMb, freeStorageMb: signals.freeStorageMb);
  }

  Future<Map<Object?, Object?>?> _readRaw() async {
    if (!_isAndroid()) return null;
    try {
      return await channel.invokeMapMethod<Object?, Object?>('getSignals');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}

/// Total RAM and free app-private storage in MB on Android; zeros elsewhere.
///
/// Shortcut for `AiroAndroidRuntimeDeviceProfiler(channel: channel).quickDeviceFit()`.
Future<AiroQuickDeviceFit> quickDeviceFit({MethodChannel? channel}) {
  return AiroAndroidRuntimeDeviceProfiler(channel: channel).quickDeviceFit();
}
