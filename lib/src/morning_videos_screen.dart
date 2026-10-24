import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'bold.dart';

class MorningVideosScreen extends StatelessWidget {
  const MorningVideosScreen({super.key});

  static final Uri firstVideo = Uri.parse(
    'https://www.youtube.com/watch?v=ahslH-8qoFY',
  );
  static final Uri secondVideo = Uri.parse(
    'https://www.youtube.com/watch?v=edMfu5IILSI',
  );

  Future<void> _open(BuildContext context, Uri url) async {
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open YouTube.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Morning videos')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Start intentionally',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'These are the two videos saved in your daily morning reminder.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          _VideoCard(
            title: 'The Truth About Retiring At Age 31',
            subtitle: 'Morning video 1',
            onTap: () => _open(context, firstVideo),
          ),
          const SizedBox(height: 12),
          _VideoCard(
            title: 'What are you doing when no one is watching?',
            subtitle: 'Morning video 2',
            onTap: () => _open(context, secondVideo),
          ),
        ],
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BoldCard(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 12,
        ),
        leading: const Icon(Icons.play_circle_outline, size: 34),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontVariations: [FontVariation('wght', 700)],
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.open_in_new),
        onTap: onTap,
      ),
    );
  }
}
