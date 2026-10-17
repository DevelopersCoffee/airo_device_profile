import 'package:airo_device_profile/airo_device_profile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _rawSignals({
  int apiLevel = 34,
  int totalMemMb = 7680,
  int availMemMb = 3000,
  int thresholdMb = 216,
  bool lowMemory = false,
  int freeStorageMb = 20000,
  int thermalStatus = 0,
  String uiMode = 'phone',
  bool hasDpad = false,
  String? securityPatch = '2026-09-05',
  int videoDecoderCount = 12,
  List<String> decoderMimeTypes = const [
    'video/avc',
    'audio/mp4a-latm',
    'video/hevc',
    'audio/opus',
  ],
}) {
  return {
    'apiLevel': apiLevel,
    'totalMemMb': totalMemMb,
    'availMemMb': availMemMb,
    'thresholdMb': thresholdMb,
    'lowMemory': lowMemory,
    'freeStorageMb': freeStorageMb,
    'thermalStatus': thermalStatus,
    'uiMode': uiMode,
    'hasDpad': hasDpad,
    'securityPatch': securityPatch,
    'videoDecoderCount': videoDecoderCount,
    'decoderMimeTypes': decoderMimeTypes,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 10, 15);
  final policy = AiroRuntimeDeviceProfilePolicy();

  group('airoAndroidSignalsFromMap', () {
    test('maps real fields from a phone', () {
      final signals = airoAndroidSignalsFromMap(_rawSignals(), now: now);

      expect(signals.apiLevel, 34);
      expect(signals.memoryMb, 7680);
      expect(signals.freeStorageMb, 20000);
      expect(signals.platformCategory, AiroNodePlatformCategory.androidMobile);
      expect(signals.memoryPressure, AiroRuntimePressureLevel.normal);
      expect(signals.storagePressure, AiroRuntimePressureLevel.normal);
      expect(signals.thermalPressure, AiroRuntimePressureLevel.normal);
      expect(signals.securityPatchAgeDays, 40);
      expect(signals.decoderCount, 12);
      expect(signals.supportedCodecs, {
        MediaCodecCapability.h264,
        MediaCodecCapability.aac,
        MediaCodecCapability.hevc,
      });
      expect(signals.remoteInputs, isEmpty);
      expect(signals.hasSecureStorage, isTrue);
      expect(signals.signalId, 'android-phone-api34');
    });

    test('uses documented defaults for unmeasured fields', () {
      final signals = airoAndroidSignalsFromMap(_rawSignals(), now: now);
      expect(signals.gpuClass, AiroRuntimeGpuClass.unknown);
      expect(signals.networkClass, AiroRuntimeNetworkClass.stableWifi);
      expect(signals.decoderFailureCount, 0);

      final overridden = airoAndroidSignalsFromMap(
        _rawSignals(),
        now: now,
        gpuClass: AiroRuntimeGpuClass.accelerated,
        networkClass: AiroRuntimeNetworkClass.ethernet,
      );
      expect(overridden.gpuClass, AiroRuntimeGpuClass.accelerated);
      expect(overridden.networkClass, AiroRuntimeNetworkClass.ethernet);
    });

    test('maps tv with dpad, tablet and unknown ui modes', () {
      final tv = airoAndroidSignalsFromMap(
        _rawSignals(uiMode: 'tv', hasDpad: true),
        now: now,
      );
      expect(tv.platformCategory, AiroNodePlatformCategory.androidTv);
      expect(tv.remoteInputs, {AiroRuntimeRemoteInput.dpad});

      final tablet = airoAndroidSignalsFromMap(
        _rawSignals(uiMode: 'tablet'),
        now: now,
      );
      expect(tablet.platformCategory, AiroNodePlatformCategory.androidMobile);

      expect(
        airoAndroidPlatformCategory(null),
        AiroNodePlatformCategory.unknown,
      );
    });

    test('tolerates a sparse map (API 24 device without thermal/patch)', () {
      final signals = airoAndroidSignalsFromMap({
        'apiLevel': 24,
        'thermalStatus': -1,
      }, now: now);
      expect(signals.apiLevel, 24);
      expect(signals.memoryMb, 0);
      expect(signals.freeStorageMb, 0);
      expect(signals.thermalPressure, AiroRuntimePressureLevel.normal);
      expect(signals.securityPatchAgeDays, 0);
      expect(signals.supportedCodecs, isEmpty);
      expect(signals.platformCategory, AiroNodePlatformCategory.unknown);
    });
  });

  group('pressure levels', () {
    test('memory', () {
      expect(
        airoAndroidMemoryPressure(
          lowMemory: true,
          availMemMb: 5000,
          thresholdMb: 200,
        ),
        AiroRuntimePressureLevel.high,
      );
      expect(
        airoAndroidMemoryPressure(
          lowMemory: false,
          availMemMb: 399,
          thresholdMb: 200,
        ),
        AiroRuntimePressureLevel.elevated,
      );
      expect(
        airoAndroidMemoryPressure(
          lowMemory: false,
          availMemMb: 400,
          thresholdMb: 200,
        ),
        AiroRuntimePressureLevel.normal,
      );
      expect(
        airoAndroidMemoryPressure(lowMemory: false),
        AiroRuntimePressureLevel.normal,
      );
    });

    test('storage follows policy thresholds', () {
      expect(
        airoAndroidStoragePressure(freeStorageMb: 127, policy: policy),
        AiroRuntimePressureLevel.high,
      );
      expect(
        airoAndroidStoragePressure(freeStorageMb: 128, policy: policy),
        AiroRuntimePressureLevel.elevated,
      );
      expect(
        airoAndroidStoragePressure(freeStorageMb: 512, policy: policy),
        AiroRuntimePressureLevel.normal,
      );
    });

    test('thermal status', () {
      const expected = {
        null: AiroRuntimePressureLevel.normal,
        -1: AiroRuntimePressureLevel.normal,
        0: AiroRuntimePressureLevel.normal,
        1: AiroRuntimePressureLevel.normal,
        2: AiroRuntimePressureLevel.elevated,
        3: AiroRuntimePressureLevel.high,
        4: AiroRuntimePressureLevel.critical,
        5: AiroRuntimePressureLevel.critical,
        6: AiroRuntimePressureLevel.critical,
      };
      expected.forEach((status, level) {
        expect(airoAndroidThermalPressure(status), level, reason: '$status');
      });
    });

    test('security patch age', () {
      expect(airoAndroidSecurityPatchAgeDays('2025-10-15', now: now), 365);
      expect(airoAndroidSecurityPatchAgeDays('2027-01-01', now: now), 0);
      expect(airoAndroidSecurityPatchAgeDays('garbage', now: now), 0);
      expect(airoAndroidSecurityPatchAgeDays(null, now: now), 0);
    });
  });

  group('AiroAndroidRuntimeDeviceProfiler', () {
    const channel = MethodChannel('airo_device_profile_test');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <MethodCall>[];

    void mockChannel(Future<Object?>? Function(MethodCall call) handler) {
      messenger.setMockMethodCallHandler(channel, (call) {
        calls.add(call);
        return handler(call);
      });
    }

    tearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockMethodCallHandler(kAiroDeviceProfileChannel, null);
      calls.clear();
      debugDefaultTargetPlatformOverride = null;
    });

    test('profiles with the policy, same as the fake profiler', () async {
      final raw = _rawSignals(uiMode: 'tv', hasDpad: true);
      mockChannel((_) async => raw);

      final profiler = AiroAndroidRuntimeDeviceProfiler(channel: channel);
      final profile = await profiler.profile(now: now);

      expect(calls.single.method, 'getSignals');
      final expected = await AiroFakeRuntimeDeviceProfiler(
        signals: airoAndroidSignalsFromMap(raw, now: now),
      ).profile(now: now);
      expect(profile, expected);
      expect(profile.signals.memoryMb, 7680);
      expect(profile.capturedAt, now);
    });

    test('critical thermal status makes the device unsupported', () async {
      mockChannel((_) async => _rawSignals(thermalStatus: 4, hasDpad: true));
      final profile = await AiroAndroidRuntimeDeviceProfiler(
        channel: channel,
      ).profile(now: now);
      expect(profile.supportTier, AiroRuntimeSupportTier.unsupported);
      expect(
        profile.constraints,
        contains(AiroRuntimeConstraintCode.thermalPressure),
      );
    });

    test('falls back to no-op on platform error', () async {
      mockChannel((_) async => throw PlatformException(code: 'boom'));
      final profile = await AiroAndroidRuntimeDeviceProfiler(
        channel: channel,
      ).profile(now: now);
      expect(
        profile,
        await const AiroNoOpRuntimeDeviceProfiler().profile(now: now),
      );
    });

    test('falls back to no-op when the plugin is missing', () async {
      // No handler registered -> MissingPluginException.
      final profile = await AiroAndroidRuntimeDeviceProfiler(
        channel: channel,
      ).profile(now: now);
      expect(profile.constraints, const [
        AiroRuntimeConstraintCode.profilerUnavailable,
      ]);
    });

    test(
      'falls back to no-op on non-Android without calling the channel',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        mockChannel((_) async => _rawSignals());
        final profiler = AiroAndroidRuntimeDeviceProfiler(channel: channel);

        final profile = await profiler.profile(now: now);
        expect(profile.constraints, const [
          AiroRuntimeConstraintCode.profilerUnavailable,
        ]);
        expect(await profiler.quickDeviceFit(), (
          memoryMb: 0,
          freeStorageMb: 0,
        ));
        expect(calls, isEmpty);
      },
    );

    test('quickDeviceFit returns memory and free storage', () async {
      mockChannel(
        (_) async => _rawSignals(totalMemMb: 3800, freeStorageMb: 2500),
      );
      final fit = await AiroAndroidRuntimeDeviceProfiler(
        channel: channel,
      ).quickDeviceFit();
      expect(fit.memoryMb, 3800);
      expect(fit.freeStorageMb, 2500);
    });

    test('top-level quickDeviceFit uses the default channel', () async {
      messenger.setMockMethodCallHandler(
        kAiroDeviceProfileChannel,
        (_) async => _rawSignals(totalMemMb: 5600, freeStorageMb: 900),
      );
      expect(await quickDeviceFit(), (memoryMb: 5600, freeStorageMb: 900));
    });
  });
}
