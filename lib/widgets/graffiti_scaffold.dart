import 'package:flutter/material.dart';

import 'graffiti_backdrop.dart';

class GraffitiScaffold extends StatelessWidget {
  const GraffitiScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.extendBody = false,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool extendBody;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const GraffitiBackdrop(),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: appBar,
          body: body,
          bottomNavigationBar: bottomNavigationBar,
          floatingActionButton: floatingActionButton,
          extendBody: extendBody,
        ),
      ],
    );
  }
}
