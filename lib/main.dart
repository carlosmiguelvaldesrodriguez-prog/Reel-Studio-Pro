import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart'; 
import 'package:google_generative_ai/google_generative_ai.dart'; 
import 'package:image/image.dart' as img; 
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'dart:io';

void main() => runApp(const MiEstudioApp());

class VideoClip {
  final String imageName;
  final double duration;
  final String transition;
  VideoClip({required this.imageName, required this.duration, required this.transition});
  factory VideoClip.fromJson(Map<String, dynamic> json) => VideoClip(
    imageName: json['image_name'] ?? json['image_id'] ?? "foto.jpg",
    duration: (json['duration_sec'] ?? json['duration'] ?? 3.0).toDouble(),
    transition: json['transition'] ?? 'crossfade'
  );
}

class MiEstudioApp extends StatelessWidget {
  const MiEstudioApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, theme: ThemeData.dark(), home: const PantallaPrincipal());
  }
}

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});
  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  List<PlatformFile> fotos = [];
  List<VideoClip> clips = [];
  bool cargando = false;
  String log = "Listo para crear Reels de 30s.";
  final TextEditingController _apiKeyController = TextEditingController();

  Future<void> seleccionar() async {
    FilePickerResult? res = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
    if (res != null) {
      setState(() { fotos = res.files; clips = []; log = "${res.files.length} fotos cargadas."; });
    }
  }

  Future<void> procesarIA() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) { setState(() => log = "❌ ERROR: Pega la API Key."); return; }
    setState(() => cargando = true);
    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: key);
      final images = <DataPart>[];
      for (var f in fotos) {
        final bytes = await File(f.path!).readAsBytes();
        final mini = img.encodeJpg(img.copyResize(img.decodeImage(bytes)!, width: 400), quality: 60);
        images.add(DataPart('image/jpeg', Uint8List.fromList(mini)));
      }
      final prompt = TextPart('Director de Arte: Crea un Reel de 30s. 10 escenas de ~3s. Alterna transiciones: crossfade, fade_black, wipeleft. JSON: {"timeline":[{"image_name":"x","duration_sec":3.0, "transition":"crossfade"}]}');
      final resp = await model.generateContent([Content.multi([...images, prompt])]);
      final data = jsonDecode(resp.text!.replaceAll('```json', '').replaceAll('```', '').trim());
      setState(() { 
        clips = (data['timeline'] as List).map((i) => VideoClip.fromJson(i)).toList();
        log = "¡Guion de ${clips.length} escenas listo! Presiona Renderizar.";
      });
    } catch (e) { setState(() => log = "Error IA: $e"); }
    finally { setState(() => cargando = false); }
  }

  Future<void> renderizarVideo() async {
    setState(() { cargando = true; log = "🎬 Iniciando FFmpeg..."; });
    // Aquí irá la lógica de renderizado
    await Future.delayed(const Duration(seconds: 5));
    setState(() { cargando = false; log = "✨ ¡VIDEO RENDERIZADO! (Simulación)"; });
  }

// --- FIN DE LA PARTE 1 DE MAIN.DART ---
