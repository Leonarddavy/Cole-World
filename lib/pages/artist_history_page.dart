import 'package:flutter/material.dart';

class ArtistHistoryPage extends StatelessWidget {
  const ArtistHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF141312), Color(0xFF241D17)],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          _HeroSummaryCard(),
          const SizedBox(height: 16),
          _SectionBlock(
            indexLabel: '1',
            title: 'Origins + Early Grind (Teens-2008)',
            summary:
                'Jermaine Lamarr Cole grew up in Fayetteville, North Carolina, started rapping as a teen, and moved to New York for college while sharpening both rap and production skills.',
            points: const [
              'In 2007, he and manager Ibrahim “Ib” Hamad began building what became Dreamville as an independent platform.',
            ],
          ),
          _SectionBlock(
            indexLabel: '2',
            title: 'Mixtape Era + Roc Nation Deal (2007-2010)',
            summary:
                'This run built his fanbase and set up his mainstream launch.',
            points: const [
              'May 4, 2007: The Come Up (mixtape).',
              'June 15, 2009: The Warm Up (mixtape).',
              '2009: Signed to Roc Nation after his mixtape momentum.',
              'Nov 12, 2010: Friday Night Lights (mixtape), often viewed as his album-ready breakout.',
            ],
          ),
          _SectionBlock(
            indexLabel: '3',
            title: 'Studio Album Run (2011-Present)',
            summary:
                'Known for concept-driven, introspective albums with social commentary and narrative detail.',
            points: const [
              '2011: Cole World: The Sideline Story (debut studio album).',
              '2013: Born Sinner (bigger and more confrontational tone).',
              '2014: 2014 Forest Hills Drive (career-defining for many fans).',
              '2016: 4 Your Eyez Only (narrative-heavy and reflective).',
              '2018: KOD (themes of addiction, escapism, and excess).',
              '2021: The Off-Season (technical, competitive rap performance).',
              'Feb 6, 2026: The Fall-Off (announced release date).',
            ],
          ),
          _SectionBlock(
            indexLabel: '4',
            title: 'Major Side Releases',
            summary:
                'Important projects outside the main studio album sequence.',
            points: const [
              '2016: Forest Hills Drive: Live From Fayetteville, NC (live album).',
              'Apr 5, 2024: Might Delete Later (mixtape), a major hip-hop conversation release with notable features.',
              'Discography references summarize catalog totals across albums, EPs, mixtapes, and singles.',
            ],
          ),
          _SectionBlock(
            indexLabel: '5',
            title: 'Dreamville Era: Label + Compilations',
            summary:
                'Dreamville, founded in 2007 by J. Cole and Ib Hamad, developed into a major artist collective and label platform.',
            points: const [
              'Core Dreamville ecosystem includes Bas, JID, EarthGang, Ari Lennox, and more.',
              '2014: Revenge of the Dreamers.',
              '2015: Revenge of the Dreamers II.',
              'Jul 5, 2019: Revenge of the Dreamers III (flagship Dreamville milestone).',
              '2022: D-Day: A Gangsta Grillz Mixtape.',
            ],
          ),
          const SizedBox(height: 10),
          _ChronologicalTimeline(),
        ],
      ),
    );
  }
}

class _HeroSummaryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF3B2C1A), Color(0xFF1E1A15)],
        ),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'J. Cole Timeline + Discography',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'A chronological view of his evolution: early grind, mixtape run, studio eras, side releases, and Dreamville milestones.',
          ),
        ],
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.indexLabel,
    required this.title,
    required this.summary,
    required this.points,
  });

  final String indexLabel;
  final String title;
  final String summary;
  final List<String> points;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xAA1E1B18),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: const Color(0xFFE2AF54),
                foregroundColor: const Color(0xFF2D1B07),
                child: Text(indexLabel),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(summary),
          const SizedBox(height: 8),
          for (final point in points)
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
  @override
  Widget build(BuildContext context) {
    final events = const [
      _Event('2007', 'The Come Up (mixtape)', 'May 4, 2007'),
      _Event('2009', 'The Warm Up + Roc Nation signing', 'June 15, 2009'),
      _Event('2010', 'Friday Night Lights (mixtape)', 'Nov 12, 2010'),
      _Event('2011', 'Cole World: The Sideline Story', 'Studio debut'),
      _Event('2013', 'Born Sinner', 'Second studio album'),
      _Event('2014', '2014 Forest Hills Drive', 'Career-defining era'),
      _Event('2014', 'Revenge of the Dreamers', 'Dreamville compilation'),
      _Event('2015', 'Revenge of the Dreamers II', 'Dreamville compilation'),
      _Event('2016', '4 Your Eyez Only', 'Narrative-focused studio album'),
      _Event(
        '2016',
        'Forest Hills Drive: Live From Fayetteville, NC',
        'Live album',
      ),
      _Event('2018', 'KOD', 'Concept album on excess/addiction themes'),
      _Event('2019', 'Revenge of the Dreamers III', 'Released Jul 5, 2019'),
      _Event('2021', 'The Off-Season', 'Technical rap showcase'),
      _Event('2022', 'D-Day: A Gangsta Grillz Mixtape', 'Dreamville release'),
      _Event('2024', 'Might Delete Later (mixtape)', 'Released Apr 5, 2024'),
      _Event('2026', 'The Fall-Off (announced)', 'Dated Feb 6, 2026'),
    ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0x991B1815),
        border: Border.all(color: Colors.white10),
      ),
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

class _Event {
  const _Event(this.year, this.title, this.note);

  final String year;
  final String title;
  final String note;
}
