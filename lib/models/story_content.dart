class StorySection {
  const StorySection({
    required this.indexLabel,
    required this.title,
    required this.summary,
    required this.points,
    required this.imageSource,
  });

  final String indexLabel;
  final String title;
  final String summary;
  final List<String> points;
  final String imageSource;

  StorySection copyWith({
    String? indexLabel,
    String? title,
    String? summary,
    List<String>? points,
    String? imageSource,
  }) {
    return StorySection(
      indexLabel: indexLabel ?? this.indexLabel,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      points: points ?? this.points,
      imageSource: imageSource ?? this.imageSource,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'indexLabel': indexLabel,
      'title': title,
      'summary': summary,
      'points': points,
      'imageSource': imageSource,
    };
  }

  static StorySection? fromJson(Map<String, dynamic> json) {
    final indexLabel = (json['indexLabel'] ?? '').toString().trim();
    final title = (json['title'] ?? '').toString().trim();
    final summary = (json['summary'] ?? '').toString().trim();
    final imageSource = (json['imageSource'] ?? '').toString().trim();
    final points = (json['points'] as List? ?? [])
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (indexLabel.isEmpty ||
        title.isEmpty ||
        summary.isEmpty ||
        imageSource.isEmpty) {
      return null;
    }
    return StorySection(
      indexLabel: indexLabel,
      title: title,
      summary: summary,
      points: points,
      imageSource: imageSource,
    );
  }
}

class StoryEvent {
  const StoryEvent({
    required this.year,
    required this.title,
    required this.note,
  });

  final String year;
  final String title;
  final String note;

  StoryEvent copyWith({String? year, String? title, String? note}) {
    return StoryEvent(
      year: year ?? this.year,
      title: title ?? this.title,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() {
    return {'year': year, 'title': title, 'note': note};
  }

  static StoryEvent? fromJson(Map<String, dynamic> json) {
    final year = (json['year'] ?? '').toString().trim();
    final title = (json['title'] ?? '').toString().trim();
    final note = (json['note'] ?? '').toString().trim();
    if (year.isEmpty || title.isEmpty || note.isEmpty) {
      return null;
    }
    return StoryEvent(year: year, title: title, note: note);
  }
}

class StoryContent {
  const StoryContent({
    required this.heroTitle,
    required this.heroSummary,
    required this.heroImageSource,
    required this.timelineImageSource,
    required this.sections,
    required this.timelineEvents,
  });

  final String heroTitle;
  final String heroSummary;
  final String heroImageSource;
  final String timelineImageSource;
  final List<StorySection> sections;
  final List<StoryEvent> timelineEvents;

  static const StoryContent _defaults = StoryContent(
    heroTitle: 'J. Cole Timeline + Discography',
    heroSummary:
        'A chronological view of his evolution: early grind, mixtape run, studio eras, side releases, and Dreamville milestones.',
    heroImageSource: 'assets/jcole2.jpg',
    timelineImageSource: 'assets/KEKE3.jpg',
    sections: [
      StorySection(
        indexLabel: '1',
        title: 'Origins + Early Grind (Teens-2008)',
        summary:
            'Jermaine Lamarr Cole grew up in Fayetteville, North Carolina, started rapping as a teen, and moved to New York for college while sharpening both rap and production skills.',
        points: [
          'In 2007, he and manager Ibrahim "Ib" Hamad began building what became Dreamville as an independent platform.',
        ],
        imageSource: 'assets/groove.jpg',
      ),
      StorySection(
        indexLabel: '2',
        title: 'Mixtape Era + Roc Nation Deal (2007-2010)',
        summary: 'This run built his fanbase and set up his mainstream launch.',
        points: [
          'May 4, 2007: The Come Up (mixtape).',
          'June 15, 2009: The Warm Up (mixtape).',
          '2009: Signed to Roc Nation after his mixtape momentum.',
          'Nov 12, 2010: Friday Night Lights (mixtape), often viewed as his album-ready breakout.',
        ],
        imageSource: 'assets/groove2.jpg',
      ),
      StorySection(
        indexLabel: '3',
        title: 'Studio Album Run (2011-Present)',
        summary:
            'Known for concept-driven, introspective albums with social commentary and narrative detail.',
        points: [
          '2011: Cole World: The Sideline Story (debut studio album).',
          '2013: Born Sinner (bigger and more confrontational tone).',
          '2014: 2014 Forest Hills Drive (career-defining for many fans).',
          '2016: 4 Your Eyez Only (narrative-heavy and reflective).',
          '2018: KOD (themes of addiction, escapism, and excess).',
          '2021: The Off-Season (technical, competitive rap performance).',
          'Feb 6, 2026: The Fall-Off (announced release date).',
        ],
        imageSource: 'assets/jcole3.jpg',
      ),
      StorySection(
        indexLabel: '4',
        title: 'Major Side Releases',
        summary: 'Important projects outside the main studio album sequence.',
        points: [
          '2016: Forest Hills Drive: Live From Fayetteville, NC (live album).',
          'Apr 5, 2024: Might Delete Later (mixtape), a major hip-hop conversation release with notable features.',
          'Discography references summarize catalog totals across albums, EPs, mixtapes, and singles.',
        ],
        imageSource: 'assets/KEKE5.jpg',
      ),
      StorySection(
        indexLabel: '5',
        title: 'Dreamville Era: Label + Compilations',
        summary:
            'Dreamville, founded in 2007 by J. Cole and Ib Hamad, developed into a major artist collective and label platform.',
        points: [
          'Core Dreamville ecosystem includes Bas, JID, EarthGang, Ari Lennox, and more.',
          '2014: Revenge of the Dreamers.',
          '2015: Revenge of the Dreamers II.',
          'Jul 5, 2019: Revenge of the Dreamers III (flagship Dreamville milestone).',
          '2022: D-Day: A Gangsta Grillz Mixtape.',
        ],
        imageSource: 'assets/KEKE6.jpg',
      ),
    ],
    timelineEvents: [
      StoryEvent(
        year: '2007',
        title: 'The Come Up (mixtape)',
        note: 'May 4, 2007',
      ),
      StoryEvent(
        year: '2009',
        title: 'The Warm Up + Roc Nation signing',
        note: 'June 15, 2009',
      ),
      StoryEvent(
        year: '2010',
        title: 'Friday Night Lights (mixtape)',
        note: 'Nov 12, 2010',
      ),
      StoryEvent(
        year: '2011',
        title: 'Cole World: The Sideline Story',
        note: 'Studio debut',
      ),
      StoryEvent(
        year: '2013',
        title: 'Born Sinner',
        note: 'Second studio album',
      ),
      StoryEvent(
        year: '2014',
        title: '2014 Forest Hills Drive',
        note: 'Career-defining era',
      ),
      StoryEvent(
        year: '2014',
        title: 'Revenge of the Dreamers',
        note: 'Dreamville compilation',
      ),
      StoryEvent(
        year: '2015',
        title: 'Revenge of the Dreamers II',
        note: 'Dreamville compilation',
      ),
      StoryEvent(
        year: '2016',
        title: '4 Your Eyez Only',
        note: 'Narrative-focused studio album',
      ),
      StoryEvent(
        year: '2016',
        title: 'Forest Hills Drive: Live From Fayetteville, NC',
        note: 'Live album',
      ),
      StoryEvent(
        year: '2018',
        title: 'KOD',
        note: 'Concept album on excess/addiction themes',
      ),
      StoryEvent(
        year: '2019',
        title: 'Revenge of the Dreamers III',
        note: 'Released Jul 5, 2019',
      ),
      StoryEvent(
        year: '2021',
        title: 'The Off-Season',
        note: 'Technical rap showcase',
      ),
      StoryEvent(
        year: '2022',
        title: 'D-Day: A Gangsta Grillz Mixtape',
        note: 'Dreamville release',
      ),
      StoryEvent(
        year: '2024',
        title: 'Might Delete Later (mixtape)',
        note: 'Released Apr 5, 2024',
      ),
      StoryEvent(
        year: '2026',
        title: 'The Fall-Off (announced)',
        note: 'Dated Feb 6, 2026',
      ),
    ],
  );

  static StoryContent defaults() => _defaults;

  StoryContent copyWith({
    String? heroTitle,
    String? heroSummary,
    String? heroImageSource,
    String? timelineImageSource,
    List<StorySection>? sections,
    List<StoryEvent>? timelineEvents,
  }) {
    return StoryContent(
      heroTitle: heroTitle ?? this.heroTitle,
      heroSummary: heroSummary ?? this.heroSummary,
      heroImageSource: heroImageSource ?? this.heroImageSource,
      timelineImageSource: timelineImageSource ?? this.timelineImageSource,
      sections: sections ?? this.sections,
      timelineEvents: timelineEvents ?? this.timelineEvents,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'heroTitle': heroTitle,
      'heroSummary': heroSummary,
      'heroImageSource': heroImageSource,
      'timelineImageSource': timelineImageSource,
      'sections': sections.map((section) => section.toJson()).toList(),
      'timelineEvents': timelineEvents.map((event) => event.toJson()).toList(),
    };
  }

  static StoryContent fromJson(Object? raw) {
    if (raw is! Map) {
      return defaults();
    }
    final json = Map<String, dynamic>.from(raw);
    final defaultsValue = defaults();

    final sections = (json['sections'] as List? ?? [])
        .whereType<Map>()
        .map((item) => StorySection.fromJson(Map<String, dynamic>.from(item)))
        .whereType<StorySection>()
        .toList();

    final events = (json['timelineEvents'] as List? ?? [])
        .whereType<Map>()
        .map((item) => StoryEvent.fromJson(Map<String, dynamic>.from(item)))
        .whereType<StoryEvent>()
        .toList();

    final heroTitle = (json['heroTitle'] ?? '').toString().trim();
    final heroSummary = (json['heroSummary'] ?? '').toString().trim();
    final heroImageSource = (json['heroImageSource'] ?? '').toString().trim();
    final timelineImageSource = (json['timelineImageSource'] ?? '')
        .toString()
        .trim();

    return StoryContent(
      heroTitle: heroTitle.isEmpty ? defaultsValue.heroTitle : heroTitle,
      heroSummary: heroSummary.isEmpty
          ? defaultsValue.heroSummary
          : heroSummary,
      heroImageSource: heroImageSource.isEmpty
          ? defaultsValue.heroImageSource
          : heroImageSource,
      timelineImageSource: timelineImageSource.isEmpty
          ? defaultsValue.timelineImageSource
          : timelineImageSource,
      sections: sections.isEmpty ? defaultsValue.sections : sections,
      timelineEvents: events.isEmpty ? defaultsValue.timelineEvents : events,
    );
  }
}
