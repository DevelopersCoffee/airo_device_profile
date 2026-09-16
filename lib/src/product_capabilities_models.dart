import 'package:equatable/equatable.dart';

enum AiroNodePlatformCategory {
  androidTv('android_tv'),
  androidMobile('android_mobile'),
  fireTv('fire_tv'),
  googleTv('google_tv'),
  appleTv('apple_tv'),
  iOS('ios'),
  macOS('macos'),
  windows('windows'),
  linux('linux'),
  web('web'),
  customEmbedded('custom_embedded'),
  unknown('unknown');

  const AiroNodePlatformCategory(this.stableId);

  final String stableId;
}

enum ProductProfileId {
  fullTv('full_tv'),
  standardTv('standard_tv'),
  liteReceiver('lite_receiver'),
  embeddedReceiver('embedded_receiver'),
  experimentalLegacy('experimental_legacy');

  const ProductProfileId(this.stableId);

  final String stableId;
}

enum MediaCodecCapability {
  h264('h264'),
  aac('aac'),
  hls('hls'),
  mpegTs('mpeg_ts'),
  hevc('hevc'),
  av1('av1'),
  dolbyVision('dolby_vision');

  const MediaCodecCapability(this.stableId);

  final String stableId;
}

class DeviceCapabilitySnapshot extends Equatable {
  const DeviceCapabilitySnapshot({
    required this.apiLevel,
    required this.memoryMb,
    required this.freeStorageMb,
    required this.decoderCount,
    required this.supportedCodecs,
    this.hasDpad = true,
    this.hasSecureStorage = true,
    this.requiresRestrictedTrust = false,
  });

  final int apiLevel;
  final int memoryMb;
  final int freeStorageMb;
  final int decoderCount;
  final Set<MediaCodecCapability> supportedCodecs;
  final bool hasDpad;
  final bool hasSecureStorage;
  final bool requiresRestrictedTrust;

  @override
  List<Object?> get props => [
    apiLevel,
    memoryMb,
    freeStorageMb,
    decoderCount,
    supportedCodecs,
    hasDpad,
    hasSecureStorage,
    requiresRestrictedTrust,
  ];
}
