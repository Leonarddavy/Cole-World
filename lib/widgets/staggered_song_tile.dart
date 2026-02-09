import 'dart:async';

import 'package:flutter/material.dart';

import '../models/collection_models.dart';

class StaggeredSongTile extends StatefulWidget {
  const StaggeredSongTile({
    super.key,
    required this.track,
    required this.index,
    required this.showPlaying,
    this.trailing,
    required this.onTap,
  });

  final Track track;
  final int index;
  final bool showPlaying;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  State<StaggeredSongTile> createState() => _StaggeredSongTileState();
}

class _StaggeredSongTileState extends State<StaggeredSongTile> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 55 * widget.index), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _visible = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0.18, 0),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF201812), Color(0xFF17110D)],
            ),
            border: Border.all(
              color: widget.showPlaying
                  ? const Color(0xFFFFB547)
                  : Colors.white12,
            ),
          ),
          child: ListTile(
            leading: const Icon(Icons.music_note),
            title: Text(widget.track.title),
            subtitle: Text(widget.track.artist),
            trailing:
                widget.trailing ??
                Icon(
                  widget.showPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                ),
            onTap: widget.onTap,
          ),
        ),
      ),
    );
  }
}
