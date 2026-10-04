import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jcole_player/widgets/floating_nav_bar.dart';

const _items = [
  NavItem(label: 'Albums', icon: Icons.album),
  NavItem(label: 'Singles', icon: Icons.music_note),
  NavItem(label: 'Features', icon: Icons.mic),
  NavItem(label: 'Playlist', icon: Icons.queue_music),
  NavItem(label: 'Story', icon: Icons.history_edu),
];

/// Hosts the bar with selection state, like the app shell does.
class _Host extends StatefulWidget {
  const _Host({required this.onSelected});

  final ValueChanged<int> onSelected;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int selected = 0;

  void select(int index) => setState(() => selected = index);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        bottomNavigationBar: FloatingNavBar(
          items: _items,
          selectedIndex: selected,
          onSelected: (index) {
            select(index);
            widget.onSelected(index);
          },
        ),
      ),
    );
  }
}

bool _onScreen(WidgetTester tester, String label) {
  final finder = find.text(label);
  if (finder.evaluate().isEmpty) {
    return false;
  }
  final rect = tester.getRect(finder);
  final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
  return rect.right > 0 && rect.left < screen.width;
}

void main() {
  testWidgets('shows three buttons and swipes to the rest', (tester) async {
    final taps = <int>[];
    await tester.pumpWidget(_Host(onSelected: taps.add));

    expect(_onScreen(tester, 'ALBUMS'), isTrue);
    expect(_onScreen(tester, 'SINGLES'), isTrue);
    expect(_onScreen(tester, 'FEATURES'), isTrue);
    expect(_onScreen(tester, 'PLAYLIST'), isFalse);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();

    expect(_onScreen(tester, 'PLAYLIST'), isTrue);
    expect(_onScreen(tester, 'STORY'), isTrue);
    expect(_onScreen(tester, 'ALBUMS'), isFalse);

    await tester.tap(find.text('STORY'));
    await tester.pumpAndSettle();
    expect(taps, [4]);
  });

  testWidgets('marks only the selected button as selected', (tester) async {
    await tester.pumpWidget(_Host(onSelected: (_) {}));
    expect(
      tester.getSemantics(find.bySemanticsLabel('Albums')),
      isSemantics(isButton: true, isSelected: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Singles')),
      isSemantics(isButton: true, isSelected: false),
    );
  });

  testWidgets('brings a selection made elsewhere into view', (tester) async {
    await tester.pumpWidget(_Host(onSelected: (_) {}));
    final host = tester.state<_HostState>(find.byType(_Host));

    host.select(3); // e.g. a shortcut jumps to Playlist
    await tester.pumpAndSettle();
    expect(_onScreen(tester, 'PLAYLIST'), isTrue);

    host.select(0); // "Back To Vault"
    await tester.pumpAndSettle();
    expect(_onScreen(tester, 'ALBUMS'), isTrue);
  });

  testWidgets('page dots jump between pages', (tester) async {
    await tester.pumpWidget(_Host(onSelected: (_) {}));
    expect(find.byType(AnimatedContainer), findsWidgets);
    // Two pages of three: tap the second dot.
    final dots = find.byWidgetPredicate(
      (widget) => widget is GestureDetector && widget.child is Padding,
    );
    expect(dots, findsNWidgets(2));
    await tester.tap(dots.last);
    await tester.pumpAndSettle();
    expect(_onScreen(tester, 'PLAYLIST'), isTrue);
  });
}
