import 'package:flutter/material.dart';
import 'package:reorderables/reorderables.dart';
import '../domain/models/clip.dart';
import 'dart:io';

class InteractiveTimeline extends StatefulWidget {
  final List<VideoClip> clips;
  final Function(List<VideoClip>) onTimelineChanged;
  final Function(VideoClip, double) onDurationChanged;
  final Function(VideoClip, String) onTransitionChanged;

  const InteractiveTimeline({
    Key? key,
    required this.clips,
    required this.onTimelineChanged,
    required this.onDurationChanged,
    required this.onTransitionChanged,
  }) : super(key: key);

  @override
  _InteractiveTimelineState createState() => _InteractiveTimelineState();
}

class _InteractiveTimelineState extends State<InteractiveTimeline> {
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      // Usamos el método removeAt y insert para reordenar directamente en la lista original
      // No creamos una copia para que los cambios se reflejen en el widget padre
      VideoClip row = widget.clips.removeAt(oldIndex);
      widget.clips.insert(newIndex, row);
    });
    widget.onTimelineChanged(widget.clips); // Notificamos al widget padre
  }

  // Define las transiciones disponibles
  final List<String> availableTransitions = ['fade', 'wipeleft', 'wiperight', 'slideup', 'slidedown', 'pixelize'];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180, // Altura fija para el timeline
      color: Colors.black26, // Fondo sutil
      child: ReorderableRow(
        onReorder: _onReorder,
        needsLongPressDraggable: false, // Arrastrar directamente sin long press
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        children: widget.clips.map((clip) => _buildClipNode(clip)).toList(),
      ),
    );
  }

  Widget _buildClipNode(VideoClip clip) {
    return Container(
      key: ValueKey(clip.id), // Clave única para el reordenamiento
      width: 120, // Ancho fijo para cada clip
      margin: const EdgeInsets.only(right: 8.0, bottom: 8.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05), // Color de fondo del clip
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.white10, width: 1),
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8.0)),
              
