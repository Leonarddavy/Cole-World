import 'package:flutter/material.dart';

import '../models/story_content.dart';
import '../widgets/graffiti_tag.dart';

class ArtistHistoryPage extends StatelessWidget {
  const ArtistHistoryPage({
    super.key,
    required this.content,
    this.isEditMode = false,
    this.onEditStory,
  });

  final StoryContent content;
  final bool isEditMode;
  final VoidCallback? onEditStory;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        if (isEditMode)
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: onEditStory,
              icon: const Icon(Icons.edit_note),
              label: const Text('Edit Story'),
            ),
          ),
        if (isEditMode) const SizedBox(height: 12),
        _HeroSummaryCard(content: content),
        const SizedBox(height: 16),
        for (final section in content.sections) _SectionBlock(section: section),
        const SizedBox(height: 10),
        _ChronologicalTimeline(
          events: content.timelineEvents,
          imageSource: content.timelineImageSource,
        ),
      ],
    );
  }
}

class _StoryImageCard extends StatelessWidget {
  const _StoryImageCard({
    required this.child,
    this.imageSource,
    this.margin,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
  });

  final Widget child;
  final String? imageSource;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  Widget _background() {
    final source = imageSource?.trim() ?? '';
    if (source.isEmpty) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF322416), Color(0xFF1D1712)],
          ),
        ),
      );
    }
    if (source.startsWith('assets/')) {
      return Image.asset(
        source,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        width: double.infinity,
        height: double.infinity,
        filterQuality: FilterQuality.high,
      );
    }
    return Image.network(
      source,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      width: double.infinity,
      height: double.infinity,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) {
        return const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF322416), Color(0xFF1D1712)],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(color: Colors.white10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 12,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(child: _background()),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x22000000), Color(0xA8000000)],
                    stops: [0.15, 1.0],
                  ),
                ),
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

class _HeroSummaryCard extends StatelessWidget {
  const _HeroSummaryCard({required this.content});

  final StoryContent content;

  @override
  Widget build(BuildContext context) {
    return _StoryImageCard(
      imageSource: content.heroImageSource,
      borderRadius: const BorderRadius.all(Radius.circular(22)),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GraffitiTag(label: 'Artist Story'),
          const SizedBox(height: 10),
          Text(
            content.heroTitle,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(content.heroSummary),
        ],
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({required this.section});

  final StorySection section;

  @override
  Widget build(BuildContext context) {
    return _StoryImageCard(
      imageSource: section.imageSource,
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: const BorderRadius.all(Radius.circular(18)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: const Color(0xFFFFB547),
                foregroundColor: const Color(0xFF2D1B07),
                child: Text(section.indexLabel),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  section.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(section.summary),
          const SizedBox(height: 8),
          for (final point in section.points)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4, right: 8),
                    child: Icon(Icons.fiber_manual_record, size: 8),
                  ),
                  Expanded(child: Text(point)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ChronologicalTimeline extends StatelessWidget {
  const _ChronologicalTimeline({
    required this.events,
    required this.imageSource,
  });

  final List<StoryEvent> events;
  final String imageSource;

  @override
  Widget build(BuildContext context) {
    return _StoryImageCard(
      imageSource: imageSource,
      borderRadius: const BorderRadius.all(Radius.circular(20)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chronological Discography View',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          for (final event in events)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFFB98945),
                foregroundColor: const Color(0xFF2D1B07),
                child: Text(
                  event.year,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              title: Text(event.title),
              subtitle: Text(event.note),
            ),
        ],
      ),
    );
  }
}
