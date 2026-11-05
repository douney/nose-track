import 'package:app_map/app_map.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('NoseTrack')),
    body: SafeArea(
      child: AppMap(
        attribution: const _MapCredits(),
        options: const MapOptions(
          initStyle: 'https://tiles.openfreemap.org/styles/liberty',
          initCenter: Geographic(lon: 2.5, lat: 46.6),
          initZoom: 5,
          maxPitch: 0,
        ),
      ),
    ),
  );
}

class _MapCredits extends StatelessWidget {
  const _MapCredits();

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomRight,
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        child: Wrap(
          children: [
            _credit(
              '© OpenStreetMap',
              'https://www.openstreetmap.org/copyright',
            ),
            _credit('© OpenMapTiles', 'https://openmaptiles.org/'),
          ],
        ),
      ),
    ),
  );

  Widget _credit(String label, String url) => TextButton(
    onPressed: () => launchUrl(Uri.parse(url)),
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(fontSize: 10),
    ),
    child: Text(label),
  );
}
