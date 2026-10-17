import 'product_capabilities_models.dart';
import 'runtime_device_profile_models.dart';

/// Thermal status reported when `PowerManager.currentThermalStatus` is not
/// available (API < 29).
const int kAiroAndroidThermalStatusUnavailable = -1;

/// Maps the raw map returned by the `airo_device_profile` method channel's
/// `getSignals` call into [AiroRuntimeDeviceSignals].
///
/// Pure Dart (no Flutter dependency) so it can be unit-tested with a fake map.
///
/// Fields measured on the device: `apiLevel`, `memoryMb`, `freeStorageMb`,
/// `memoryPressure`, `storagePressure`, `thermalPressure`, `platformCategory`,
/// `securityPatchAgeDays`, `decoderCount`, `supportedCodecs` (best effort,
/// decoder MIME types only) and `remoteInputs` (D-pad only).
///
/// Fields with no permission-free source use defaults:
/// - `gpuClass`: [gpuClass], default [AiroRuntimeGpuClass.unknown].
/// - `networkClass`: [networkClass], default
///   [AiroRuntimeNetworkClass.stableWifi] (not measured; reading it would need
///   `ACCESS_NETWORK_STATE`).
/// - `hasSecureStorage`: `true` when `apiLevel >= 23` (Android Keystore).
/// - `decoderFailureCount`: `0`.
/// - Container formats (`hls`, `mpegTs`) are never reported, because they are
///   not decoders. Pass a policy with matching `baselineCodecs` if needed.
AiroRuntimeDeviceSignals airoAndroidSignalsFromMap(
  Map<Object?, Object?> raw, {
  required DateTime now,
  AiroRuntimeDeviceProfilePolicy? policy,
  AiroRuntimeGpuClass gpuClass = AiroRuntimeGpuClass.unknown,
  AiroRuntimeNetworkClass networkClass = AiroRuntimeNetworkClass.stableWifi,
}) {
  final effectivePolicy = policy ?? AiroRuntimeDeviceProfilePolicy();
  final apiLevel = _int(raw['apiLevel']);
  final memoryMb = _int(raw['totalMemMb']);
  final freeStorageMb = _int(raw['freeStorageMb']);
  final uiMode = raw['uiMode'] is String ? raw['uiMode']! as String : null;
  final mimeTypes = raw['decoderMimeTypes'] is List
      ? (raw['decoderMimeTypes']! as List).whereType<String>()
      : const <String>[];

  return AiroRuntimeDeviceSignals(
    signalId: 'android-${uiMode ?? 'unknown'}-api$apiLevel',
    platformCategory: airoAndroidPlatformCategory(uiMode),
    apiLevel: apiLevel,
    memoryMb: memoryMb,
    freeStorageMb: freeStorageMb,
    gpuClass: gpuClass,
    decoderCount: _int(raw['videoDecoderCount']),
    supportedCodecs: airoAndroidCodecsFromMimeTypes(mimeTypes),
    remoteInputs: {if (raw['hasDpad'] == true) AiroRuntimeRemoteInput.dpad},
    networkClass: networkClass,
    memoryPressure: airoAndroidMemoryPressure(
      lowMemory: raw['lowMemory'] == true,
      availMemMb: _intOrNull(raw['availMemMb']),
      thresholdMb: _intOrNull(raw['thresholdMb']),
    ),
    storagePressure: airoAndroidStoragePressure(
      freeStorageMb: freeStorageMb,
      policy: effectivePolicy,
    ),
    thermalPressure: airoAndroidThermalPressure(
      _intOrNull(raw['thermalStatus']),
    ),
    hasSecureStorage: apiLevel >= 23,
    securityPatchAgeDays: airoAndroidSecurityPatchAgeDays(
      raw['securityPatch'] is String ? raw['securityPatch']! as String : null,
      now: now,
    ),
  );
}

/// `lowMemory` -> high; `availMem < threshold * 2` -> elevated; else normal.
AiroRuntimePressureLevel airoAndroidMemoryPressure({
  required bool lowMemory,
  int? availMemMb,
  int? thresholdMb,
}) {
  if (lowMemory) return AiroRuntimePressureLevel.high;
  if (availMemMb != null &&
      thresholdMb != null &&
      thresholdMb > 0 &&
      availMemMb < thresholdMb * 2) {
    return AiroRuntimePressureLevel.elevated;
  }
  return AiroRuntimePressureLevel.normal;
}

/// Below `legacyFreeStorageMb` -> high; below `fullFreeStorageMb` ->
/// elevated; else normal.
AiroRuntimePressureLevel airoAndroidStoragePressure({
  required int freeStorageMb,
  required AiroRuntimeDeviceProfilePolicy policy,
}) {
  if (freeStorageMb < policy.legacyFreeStorageMb) {
    return AiroRuntimePressureLevel.high;
  }
  if (freeStorageMb < policy.fullFreeStorageMb) {
    return AiroRuntimePressureLevel.elevated;
  }
  return AiroRuntimePressureLevel.normal;
}

/// Maps `PowerManager.THERMAL_STATUS_*`: none/light (0-1) -> normal,
/// moderate (2) -> elevated, severe (3) -> high, critical and above (>= 4) ->
/// critical. Unavailable (API < 29, `-1` or `null`) -> normal.
AiroRuntimePressureLevel airoAndroidThermalPressure(int? thermalStatus) {
  if (thermalStatus == null || thermalStatus < 2) {
    return AiroRuntimePressureLevel.normal;
  }
  return switch (thermalStatus) {
    2 => AiroRuntimePressureLevel.elevated,
    3 => AiroRuntimePressureLevel.high,
    _ => AiroRuntimePressureLevel.critical,
  };
}

/// `tv` -> [AiroNodePlatformCategory.androidTv]; `phone` and `tablet` ->
/// [AiroNodePlatformCategory.androidMobile] (the model has no tablet
/// category); anything else -> [AiroNodePlatformCategory.unknown].
AiroNodePlatformCategory airoAndroidPlatformCategory(String? uiMode) {
  return switch (uiMode) {
    'tv' => AiroNodePlatformCategory.androidTv,
    'phone' || 'tablet' => AiroNodePlatformCategory.androidMobile,
    _ => AiroNodePlatformCategory.unknown,
  };
}

/// Maps decoder MIME types to [MediaCodecCapability] values.
Set<MediaCodecCapability> airoAndroidCodecsFromMimeTypes(
  Iterable<String> mimeTypes,
) {
  const byMime = {
    'video/avc': MediaCodecCapability.h264,
    'audio/mp4a-latm': MediaCodecCapability.aac,
    'video/hevc': MediaCodecCapability.hevc,
    'video/av01': MediaCodecCapability.av1,
    'video/dolby-vision': MediaCodecCapability.dolbyVision,
  };
  return {for (final mime in mimeTypes) ?byMime[mime.toLowerCase()]};
}

/// Days between `Build.VERSION.SECURITY_PATCH` (`YYYY-MM-DD`) and [now].
/// Returns 0 when the patch level is missing or unparseable.
int airoAndroidSecurityPatchAgeDays(
  String? securityPatch, {
  required DateTime now,
}) {
  if (securityPatch == null || securityPatch.isEmpty) return 0;
  final patch = DateTime.tryParse(securityPatch);
  if (patch == null) return 0;
  final days = now
      .toUtc()
      .difference(DateTime.utc(patch.year, patch.month, patch.day))
      .inDays;
  return days < 0 ? 0 : days;
}

int _int(Object? value) => _intOrNull(value) ?? 0;

int? _intOrNull(Object? value) => switch (value) {
  final int v => v,
  final num v => v.toInt(),
  _ => null,
};
