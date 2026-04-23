import 'package:flutter/material.dart';
import 'package:reorderables/reorderables.dart';
import '../domain/models/clip.dart';

class InteractiveTimeline extends StatefulWidget {
  final List<VideoClip> clips;
  final Function(List<VideoClip>) onTimelineChanged;

  const InteractiveTimeline({Key? key, required this.clips, required this.onTimelineChanged}) : super(key: key);

  @override
  _InteractiveTimelineState createState() => _InteractiveTimelineState();
}

class _InteractiveTimelineState extends State<InteractiveTimeline> {
  late List<VideoClip> _clips;

  @override
  void initState() {
    super.initState();
    _clips = List.from(widget.clips);
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      VideoClip row = _clips.removeAt(oldIndex);
      _clips.insert(newIndex, row);
    });
    widget.onTimelineChanged(_clips);
  }

  @override
  Widget build(BuildContext context) {
    // Dark Mode Profesional UI
    return Container(
      height: 160,
      color: const Color(0xFF121212), // Fondo oscuro profundo
      child: ReorderableRow(
        onReorder: _onReorder,
        needsLongPressDraggable: false,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        children: _clips.map((clip) => _buildClipNode(clip)).toList(),
      ),
    );
  }

  Widget _buildClipNode(VideoClip clip) {
    return Container(
      key: ValueKey(clip.id),
      width: 120,
      margin: const EdgeInsets.only(right: 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: const Color(0xFF333333), width: 1),
      ),
      child: Column(
        children:[
          // Preview de la imagen (Placeholder para tu lógica local)
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8.0)),
              child: Image.network(clip.imagePath, fit: BoxFit.cover, width: double.infinity),
            ),
          ),
          // Controles de Recorte y Transición
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children:[
                Text('${clip.durationSeconds}s', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.animation, color: Colors.amber, size: 16),
                  color: const Color(0xFF2C2C2C),
                  onSelected: (val) {
                    setState(() => clip.transitionType = val);
                    widget.onTimelineChanged(_clips);
                  },
                  itemBuilder: (context) =>['fade', 'wipeleft', 'wiperight', 'circlecrop', 'pixelize']
                      .map((t) => PopupMenuItem(value: t, child: Text(t, style: const TextStyle(color: Colors.white))))
                      .toList(),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
