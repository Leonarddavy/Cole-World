import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/artist_editions.dart';
import '../models/app_tab.dart';
import '../theme/card_shapes.dart';
import '../theme/graffiti_surfaces.dart';
import '../widgets/artist_edition_tile.dart';
import '../widgets/graffiti_scaffold.dart';

/// Every preference in one place (previously spread over the ⋮ menu, some
/// behind Edit Mode).
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.tabLayout,
    required this.onTabLayoutChanged,
    required this.backgroundRotation,
    required this.onBackgroundRotationChanged,
    required this.customBackgroundCount,
    required this.onUploadBackgrounds,
    required this.onResetBackgrounds,
    required this.onOpenThemeEditor,
    required this.onlineLyrics,
    required this.onSetOnlineLyrics,
    required this.editMode,
    required this.onEditModeChanged,
    required this.onRescanSongInfo,
    required this.onImportMusic,
    required this.onReplayIntro,
    required this.youtubeApiKeySet,
    required this.onEditYoutubeApiKey,
    required this.cardShape,
    required this.onCardShapeChanged,
    required this.artist,
    required this.onArtistChanged,
  });

  final TabLayout tabLayout;
  final ValueChanged<TabLayout> onTabLayoutChanged;
  final bool backgroundRotation;
  final ValueChanged<bool> onBackgroundRotationChanged;
  final int customBackgroundCount;

  /// Picks images; resolves to how many custom backgrounds there are now.
  final Future<int> Function() onUploadBackgrounds;
  final Future<void> Function() onResetBackgrounds;
  final Future<void> Function() onOpenThemeEditor;
  final bool onlineLyrics;

  /// Resolves to whether online lyrics ended up on (turning them on asks
  /// for confirmation first).
  final Future<bool> Function(bool enabled) onSetOnlineLyrics;
  final bool editMode;
  final ValueChanged<bool> onEditModeChanged;
  final Future<void> Function() onRescanSongInfo;
  final Future<void> Function() onImportMusic;
  final VoidCallback onReplayIntro;
  final bool youtubeApiKeySet;
  final CardShapeStyle cardShape;

  /// Applies right away, so the whole app previews the new shape.
  final ValueChanged<CardShapeStyle> onCardShapeChanged;

  /// Resolves to whether a key is set afterwards.
  final Future<bool> Function() onEditYoutubeApiKey;

  /// Whose discography, story and theme the app is showing.
  final ArtistProfile artist;

  /// Switching changes the whole app, so the caller closes Settings first.
  final ValueChanged<ArtistProfile> onArtistChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TabLayout _tabLayout = widget.tabLayout;
  late bool _backgroundRotation = widget.backgroundRotation;
  late int _customBackgroundCount = widget.customBackgroundCount;
  late bool _onlineLyrics = widget.onlineLyrics;
  late bool _editMode = widget.editMode;
  late bool _youtubeApiKeySet = widget.youtubeApiKeySet;
  late CardShapeStyle _cardShape = widget.cardShape;

  Future<void> _pickCardShape() async {
    final picked = await showModalBottomSheet<CardShapeStyle>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _CardShapePicker(selected: _cardShape),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _cardShape = picked);
    widget.onCardShapeChanged(picked);
  }

  void _updateTabs(TabLayout next) {
    setState(() => _tabLayout = next);
    widget.onTabLayoutChanged(next);
  }

  void _reorderTabs(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final order = [..._tabLayout.order];
    order.insert(newIndex, order.removeAt(oldIndex));
    _updateTabs(_tabLayout.copyWith(order: order));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inBottomBar = _tabLayout.visible.take(3).toSet();

    return GraffitiScaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const _SectionTitle('Artist'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'Each artist has their own library, story, theme and history.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final profile in ArtistProfile.values)
            ArtistEditionTile(
              edition: artistEdition(profile),
              selected: profile == widget.artist,
              onTap: profile == widget.artist
                  ? null
                  : () => widget.onArtistChanged(profile),
            ),
          const _SectionTitle('Appearance'),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Fonts & colors'),
            subtitle: const Text('Accent colors, background tone and fonts'),
            onTap: widget.onOpenThemeEditor,
          ),
          ListTile(
            leading: const Icon(Icons.crop_square_rounded),
            title: const Text('Card shape'),
            subtitle: Text(
              '${_cardShape.label}: ${_cardShape.description.toLowerCase()}',
            ),
            trailing: _ShapeSwatch(style: _cardShape),
            onTap: _pickCardShape,
          ),
          ListTile(
            leading: const Icon(Icons.wallpaper_outlined),
            title: const Text('Add background images'),
            subtitle: Text(
              _customBackgroundCount == 0
                  ? 'Using the built-in graffiti photos'
                  : '$_customBackgroundCount custom '
                        'image${_customBackgroundCount == 1 ? '' : 's'}',
            ),
            onTap: () async {
              final count = await widget.onUploadBackgrounds();
              if (mounted) {
                setState(() => _customBackgroundCount = count);
              }
            },
          ),
          if (_customBackgroundCount > 0)
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Use the built-in backgrounds'),
              onTap: () async {
                await widget.onResetBackgrounds();
                if (mounted) {
                  setState(() => _customBackgroundCount = 0);
                }
              },
            ),
          SwitchListTile(
            secondary: const Icon(Icons.slideshow_outlined),
            title: const Text('Rotate background images'),
            subtitle: const Text(
              'Slowly changes the background. Off keeps one image per visit.',
            ),
            value: _backgroundRotation,
            onChanged: (value) {
              setState(() => _backgroundRotation = value);
              widget.onBackgroundRotationChanged(value);
            },
          ),
          const _SectionTitle('Navigation'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Drag to reorder. The first three show in the bottom bar; '
              'swipe the bar for the rest.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorder: _reorderTabs,
            children: [
              for (final (index, tab) in _tabLayout.order.indexed)
                ListTile(
                  key: ValueKey(tab),
                  leading: Icon(tab.icon),
                  title: Text(tab.label),
                  subtitle: _tabLayout.hidden.contains(tab)
                      ? const Text('Hidden')
                      : inBottomBar.contains(tab)
                      ? const Text('In the bottom bar')
                      : const Text('Swipe the bar to reach it'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: !_tabLayout.hidden.contains(tab),
                        onChanged: tab.canHide
                            ? (visible) => _updateTabs(
                                _tabLayout.withVisibility(tab, visible),
                              )
                            : null,
                      ),
                      ReorderableDragStartListener(
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.drag_handle),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const _SectionTitle('Lyrics'),
          SwitchListTile(
            secondary: const Icon(Icons.travel_explore),
            title: const Text('Find lyrics online'),
            subtitle: const Text(
              'Looks songs up on LRCLIB when there are no lyrics on this '
              'device. Sends the title, artist and length only.',
            ),
            value: _onlineLyrics,
            onChanged: (value) async {
              final result = await widget.onSetOnlineLyrics(value);
              if (mounted) {
                setState(() => _onlineLyrics = result);
              }
            },
          ),
          const _SectionTitle('Music videos'),
          ListTile(
            leading: const Icon(Icons.smart_display_outlined),
            title: const Text('YouTube API key'),
            subtitle: Text(
              _youtubeApiKeySet
                  ? 'Set: music videos are found automatically'
                  : 'Not set: paste YouTube links on the lyrics screen instead',
            ),
            onTap: () async {
              final set = await widget.onEditYoutubeApiKey();
              if (mounted) {
                setState(() => _youtubeApiKeySet = set);
              }
            },
          ),
          const _SectionTitle('Library'),
          ListTile(
            leading: const Icon(Icons.download_rounded),
            title: const Text('Import music'),
            subtitle: const Text(
              'Turn a folder or a set of files into an album',
            ),
            onTap: widget.onImportMusic,
          ),
          if (!kIsWeb)
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Rescan song info'),
              subtitle: const Text(
                'Re-read titles, artists, covers and lengths from your files',
              ),
              onTap: widget.onRescanSongInfo,
            ),
          const _SectionTitle('Editing'),
          SwitchListTile(
            secondary: const Icon(Icons.edit_note),
            title: const Text('Edit mode'),
            subtitle: const Text('Shows the editor for the Story tab'),
            value: _editMode,
            onChanged: (value) {
              setState(() => _editMode = value);
              widget.onEditModeChanged(value);
            },
          ),
          const _SectionTitle('About'),
          ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: const Text('Replay the intro'),
            onTap: widget.onReplayIntro,
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Open-source licenses'),
            onTap: () =>
                showLicensePage(context: context, applicationName: 'II.VI'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Semantics(
        header: true,
        child: Text(
          title.toUpperCase(),
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
            letterSpacing: 1.4,
          ),
        ),
      ),
    );
  }
}

/// A small cover-and-card preview of a [CardShapeStyle].
class _ShapeSwatch extends StatelessWidget {
  const _ShapeSwatch({required this.style});

  final CardShapeStyle style;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shapes = CardShapes(style);
    return SizedBox(
      width: 92,
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox.square(
            dimension: 36,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                shape: shapes.artwork(8),
                gradient: scheme.accentGradient,
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 48,
            height: 26,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                shape: shapes.card(10, side: BorderSide(color: scheme.outline)),
                gradient: scheme.cardGradient,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardShapePicker extends StatelessWidget {
  const _CardShapePicker({required this.selected});

  final CardShapeStyle selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Card shape', style: theme.textTheme.titleLarge),
          ),
          for (final style in CardShapeStyle.values)
            ListTile(
              selected: style == selected,
              leading: _ShapeSwatch(style: style),
              title: Text(style.label),
              subtitle: Text(style.description),
              trailing: style == selected ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, style),
            ),
        ],
      ),
    );
  }
}
