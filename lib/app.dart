import 'package:app_ui/app_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'dev/phone_preview.dart';
import 'home_screen.dart';

class NoseTrackApp extends StatelessWidget {
  const NoseTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    Widget app([TargetPlatform? platform]) => MaterialApp(
      title: 'NoseTrack',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(accent: const Color(0xFF27765B))
          .copyWith(platform: platform),
      home: const HomeScreen(),
    );

    return !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS
        ? PhonePreview(builder: app)
        : app();
  }
}
