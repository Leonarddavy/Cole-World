import 'package:flutter/material.dart';

import 'collection_models.dart';

/// The main sections of the app, shown as navigation buttons.
enum AppTab { home, albums, singles, features, playlists, story }

extension AppTabUi on AppTab {
  String get label => switch (this) {
    AppTab.home => 'Home',
    AppTab.albums => 'Albums',
    AppTab.singles => 'Singles',
    AppTab.features => 'Features',
    AppTab.playlists => 'Playlists',
    AppTab.story => 'Story',
  };

  IconData get icon => switch (this) {
    AppTab.home => Icons.home_outlined,
    AppTab.albums => Icons.library_books_outlined,
    AppTab.singles => Icons.music_note_outlined,
    AppTab.features => Icons.mic_external_on_outlined,
    AppTab.playlists => Icons.playlist_play_outlined,
    AppTab.story => Icons.history_edu_outlined,
  };

  IconData get selectedIcon => switch (this) {
    AppTab.home => Icons.home_rounded,
    AppTab.albums => Icons.library_books,
    AppTab.singles => Icons.music_note,
    AppTab.features => Icons.mic_external_on,
    AppTab.playlists => Icons.playlist_play,
    AppTab.story => Icons.history_edu,
  };

  /// The collection type a tab lists, if it lists one.
  CollectionType? get collectionType => switch (this) {
    AppTab.albums => CollectionType.album,
    AppTab.singles => CollectionType.single,
    AppTab.features => CollectionType.feature,
    AppTab.playlists => CollectionType.playlist,
    AppTab.home || AppTab.story => null,
  };

  /// Home can't be hidden, so there is always somewhere to land.
  bool get canHide => this != AppTab.home;
}

/// Which tabs show, and in what order. The first three are visible in the
/// bottom bar without swiping.
class TabLayout {
  const TabLayout({required this.order, this.hidden = const {}});

  static const TabLayout defaults = TabLayout(order: AppTab.values);

  final List<AppTab> order;
  final Set<AppTab> hidden;

  List<AppTab> get visible => [
    for (final tab in order)
      if (!hidden.contains(tab)) tab,
  ];

  TabLayout copyWith({List<AppTab>? order, Set<AppTab>? hidden}) {
    return TabLayout(order: order ?? this.order, hidden: hidden ?? this.hidden);
  }

  TabLayout withVisibility(AppTab tab, bool visible) {
    if (!tab.canHide) {
      return this;
    }
    final next = {...hidden};
    if (visible) {
      next.remove(tab);
    } else {
      next.add(tab);
    }
    return copyWith(hidden: next);
  }

  Map<String, dynamic> toJson() => {
    'order': [for (final tab in order) tab.name],
    'hidden': [for (final tab in hidden) tab.name],
  };

  /// Reads a saved layout, tolerating unknown or missing tabs (e.g. after an
  /// update adds one): every tab appears exactly once.
  static TabLayout fromJson(Object? raw) {
    if (raw is! Map) {
      return defaults;
    }
    AppTab? parse(Object? name) {
      for (final tab in AppTab.values) {
        if (tab.name == name) {
          return tab;
        }
      }
      return null;
    }

    final order = <AppTab>[];
    for (final name in raw['order'] is List ? raw['order'] as List : const []) {
      final tab = parse(name);
      if (tab != null && !order.contains(tab)) {
        order.add(tab);
      }
    }
    for (final tab in AppTab.values) {
      if (!order.contains(tab)) {
        order.add(tab);
      }
    }
    final hidden = <AppTab>{
      for (final name
          in raw['hidden'] is List ? raw['hidden'] as List : const [])
        ?parse(name),
    }..removeWhere((tab) => !tab.canHide);
    return TabLayout(order: order, hidden: hidden);
  }
}
