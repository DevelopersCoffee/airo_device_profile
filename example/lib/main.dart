import 'dart:convert';

import 'package:airo_device_profile/airo_device_profile.dart';
import 'package:flutter/material.dart';

void main() => runApp(const ProfileApp());

class ProfileApp extends StatelessWidget {
  const ProfileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: ProfilePage());
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _text = 'Profiling...';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profiler = AiroAndroidRuntimeDeviceProfiler();
    final profile = await profiler.profile(now: DateTime.now());
    final fit = await quickDeviceFit();
    const encoder = JsonEncoder.withIndent('  ');
    final text = [
      'quickDeviceFit: memoryMb=${fit.memoryMb}, '
          'freeStorageMb=${fit.freeStorageMb}',
      'profile: ${encoder.convert(profile.toPublicMap())}',
      'signals: ${encoder.convert(profile.signals.toPublicMap())}',
    ].join('\n\n');
    debugPrint(text);
    if (mounted) setState(() => _text = text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('airo_device_profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          _text,
          style: const TextStyle(fontFamily: 'monospace'),
        ),
      ),
    );
  }
}
