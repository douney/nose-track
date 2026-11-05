import 'package:flutter/material.dart';

enum PreviewDevice {
  iphone11('iPhone XR / 11', Size(414, 896), top: 44),
  androidStandard('Android · standard', Size(360, 800), android: true),
  androidMedium('Android · intermédiaire', Size(384, 832), android: true),
  iphone14('iPhone 12 / 13 / 14', Size(390, 844)),
  androidLarge('Android · grand', Size(393, 873), android: true),
  androidCompact('Android · compact', Size(360, 780), android: true),
  iphoneSE('iPhone SE', Size(375, 667), top: 20, bottom: 0),
  iphone15('iPhone 15 / 16', Size(393, 852), top: 59),
  iphone16Pro('iPhone 16 Pro', Size(402, 874), top: 62),
  iphone16ProMax('iPhone 16 Pro Max', Size(440, 956), top: 62);

  const PreviewDevice(
    this.label,
    this.size, {
    this.android = false,
    this.top = 47,
    this.bottom = 34,
  });
  final String label;
  final Size size;
  final bool android;
  final double top, bottom;
  TargetPlatform get platform =>
      android ? TargetPlatform.android : TargetPlatform.iOS;
  EdgeInsets get safeArea => android
      ? const EdgeInsets.symmetric(vertical: 24)
      : EdgeInsets.only(top: top, bottom: bottom);
}

/// Development tools around the real app. Native services keep the host platform.
class PhonePreview extends StatefulWidget {
  const PhonePreview({super.key, required this.builder});

  static const panelWidth = 260.0;
  static const padding = 16.0;
  static const safeArea = EdgeInsets.only(top: 47, bottom: 34);
  final Widget Function(TargetPlatform platform) builder;

  @override
  State<PhonePreview> createState() => _PhonePreviewState();
}

class _PhonePreviewState extends State<PhonePreview> {
  PreviewDevice? device = PreviewDevice.iphone14;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'NoseTrack · Aperçu mobile',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorSchemeSeed: const Color(0xFF27765B),
      scaffoldBackgroundColor: const Color(0xFFEAECF2),
    ),
    builder: (context, _) => Scaffold(
      body: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(PhonePreview.padding),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = device?.size ?? constraints.biggest;
                  final insets = device?.safeArea ?? PhonePreview.safeArea;
                  return Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: size.width,
                        height: size.height,
                        child: ClipRect(
                          child: MediaQuery(
                            data: MediaQuery.of(context).copyWith(
                              size: size,
                              padding: insets,
                              viewPadding: insets,
                              viewInsets: EdgeInsets.zero,
                              systemGestureInsets: EdgeInsets.only(
                                bottom: insets.bottom,
                              ),
                            ),
                            child: widget.builder(
                              device?.platform ?? TargetPlatform.iOS,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          SizedBox(
            width: PhonePreview.panelWidth,
            child: Material(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 24, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Aperçu mobile',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Formats d’écran courants',
                          style: TextStyle(color: Colors.black54, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      children: [
                        _option(
                          key: const Key('preview-free'),
                          title: 'Taille libre',
                          subtitle: 'Suit la fenêtre',
                          selected: device == null,
                          onTap: () => setState(() => device = null),
                        ),
                        const Divider(),
                        for (final preset in PreviewDevice.values)
                          _option(
                            key: ValueKey('preview-${preset.name}'),
                            title: preset.label,
                            subtitle:
                                '${preset.size.width.toInt()} × ${preset.size.height.toInt()}',
                            selected: preset == device,
                            onTap: () => setState(() => device = preset),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Pixels logiques · marges simulées\n'
                      '${device == null ? 'La taille suit la fenêtre.' : 'Zoom automatique pour tenir dans la fenêtre.'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _option({
    required Key key,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) => ListTile(
    key: key,
    selected: selected,
    selectedTileColor: const Color(0xFFE5F2EB),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    leading: Icon(
      selected ? Icons.radio_button_checked : Icons.radio_button_off,
      size: 20,
    ),
    title: Text(
      title,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
    subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
    onTap: onTap,
  );
}
