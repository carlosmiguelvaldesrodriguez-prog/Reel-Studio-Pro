import 'package:flutter/material.dart';
import 'package:reorderables/reorderables.dart';
import '../domain/models/clip.dart';
import 'dart:io';

class InteractiveTimeline extends StatefulWidget {
  final List<VideoClip> clips;
  final Function(List<VideoClip>) onTimelineChanged;
  const InteractiveTimeline({Key? key, required this.clips, required this.onTimelineChanged}) : super(key: key);
  @override
  _InteractiveTimelineState createState() => _InteractiveTimelineState();
}

class _InteractiveTimelineState extends State<InteractiveTimeline> {
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      VideoClip row = widget.clips.removeAt(oldIndex);
      widget.clips.insert(newIndex, row);
    });
    widget.onTimelineChanged(widget.clips);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(15)),
      child: ReorderableRow(
        onReorder: _onReorder,
        children: widget.clips.map((clip) => Container(
          key: ValueKey(clip.id),
          width: 100,
          margin: const EdgeInsets.only(right: 10),
          child: Column(
            children: [
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(clip.imagePath), fit: BoxFit.cover))),
              Text("${clip.durationSeconds}s", style: const TextStyle(fontSize: 10)),
              Icon(Icons.swap_horiz, size: 16, color: Colors.cyanAccent),
            ],
          ),
        )).toList(),
      ),
    );
  }
}
