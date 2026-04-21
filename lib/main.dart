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
  String log = "Cerebro Conectado. Paso Final: Activar el Músculo.";
  final TextEditingController _apiKeyController = TextEditingController();

  Future<void> seleccionar() async {
    FilePickerResult? res = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
    if (res != null) setState(() { fotos = res.files; clips = []; log = "Fotos cargadas."; });
  }

  Future<void> procesarIA() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) { setState(() => log = "❌ ERROR: Pega la API Key."); return; }
    setState(() => cargando = true);
    try {
      final model = GenerativeModel(model: 'gemini-3-flash-preview', apiKey: key);
      final images = <DataPart>[];
      for (var f in fotos) {
        final bytes = await File(f.path!).readAsBytes();
        final mini = img.encodeJpg(img.copyResize(img.decodeImage(bytes)!, width: 400), quality: 60);
        imageParts.add(DataPart('image/jpeg', Uint8List.fromList(mini)));
      }
      final prompt = TextPart('Director Pro: Crea Reel 30s. 10 escenas. Transiciones variadas. JSON: {"timeline":[{"image_name":"x","duration_sec":3.0, "transition":"crossfade"}]}');
      final resp = await model.generateContent([Content.multi([...images, prompt])]);
      final data = jsonDecode(resp.text!.replaceAll('```json', '').replaceAll('```', '').trim());
      setState(() { 
        clips = (data['timeline'] as List).map((i) => VideoClip.fromJson(i)).toList();
        log = "¡GUION LISTO! Presiona RENDERIZAR para crear el video real.";
      });
    } catch (e) { setState(() => log = "Error: $e"); }
    finally { setState(() => cargando = false); }
  }

  // --- EL MÚSCULO FINAL (FFMPEG REAL) ---
  Future<void> renderizarVideo() async {
    setState(() { cargando = true; log = "🎬 FABRICANDO VIDEO MP4... Por favor espera."; });

    // 1. Buscamos el nombre de la primera foto para saber en qué carpeta estamos
    String carpetaBase = File(fotos[0].path!).parent.path;
    String rutaSalida = "$carpetaBase/Reel_IA_Final.mp4";

    // 2. Creamos el archivo de guion para FFmpeg
    String guionTexto = "";
    for (var clip in clips) {
      // Buscamos la ruta real de la foto que eligió la IA
      String rutaFoto = fotos.firstWhere((f) => f.name.contains(clip.imageName.replaceAll("input_file_", "")), orElse: () => fotos[0]).path!;
      guionTexto += "file '$rutaFoto'\nduration ${clip.duration}\n";
    }
    
    File fileGuion = File('$carpetaBase/guion.txt');
    await fileGuion.writeAsString(guionTexto);

    // 3. Ejecutamos el motor FFmpeg
    // (Pegamos las fotos + la música y lo guardamos en el Escritorio)
    String comando = "-f concat -safe 0 -i '${fileGuion.path}' -vsync vfr -pix_fmt yuv420p -y '$rutaSalida'";

    FFmpegKit.execute(comando).then((session) async {
      final returnCode = await session.getReturnCode();
      if (returnCode!.isValueSuccess()) {
        setState(() { cargando = false; log = "✨ ¡ÉXITO! Video guardado en: $rutaSalida"; });
      } else {
        setState(() { cargando = false; log = "❌ ERROR EN RENDERIZADO. Verifica FFmpeg."; });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IA REEL STUDIO - VERSIÓN FINAL')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              SizedBox(width: 450, child: TextField(controller: _apiKeyController, obscureText: true, decoration: const InputDecoration(labelText: '🔑 API Key'))),
              const SizedBox(height: 20),
              Text(log, textAlign: TextAlign.center, style: const TextStyle(color: Colors.cyanAccent)),
              const SizedBox(height: 20),
              if (!cargando) ...[
                ElevatedButton(onPressed: seleccionar, child: const Text("1. SUBIR FOTOS")),
                const SizedBox(height: 10),
                if (fotos.isNotEmpty) ElevatedButton(onPressed: procesarIA, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text("2. GENERAR GUION")),
                const SizedBox(height: 10),
                if (clips.isNotEmpty) ElevatedButton(onPressed: renderizarVideo, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue), child: const Text("3. RENDERIZAR VIDEO FINAL")),
              ],
              if (cargando) const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
