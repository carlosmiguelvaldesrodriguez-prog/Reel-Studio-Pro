import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart'; 
import 'package:google_generative_ai/google_generative_ai.dart'; 
import 'package:image/image.dart' as img; 
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http; // Para descargar la música
import 'package:path_provider/path_provider.dart'; // Para rutas temporales

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
  String log = "Pega tu API Key y sube tus fotos.";
  final TextEditingController _apiKeyController = TextEditingController();
  String? rutaMusicaSeleccionada; // Para guardar dónde está la música

  Future<void> seleccionar() async {
    FilePickerResult? res = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
    if (res != null) setState(() { fotos = res.files; clips = []; log = "${res.files.length} fotos cargadas."; });
  }

  void limpiarTodo() {
    setState(() { fotos = []; clips = []; rutaMusicaSeleccionada = null; log = "Listo para crear Reels de 30s."; });
  }

  // NUEVA FUNCIÓN: DESCARGAR MÚSICA AUTOMÁTICAMENTE
  Future<void> descargarMusica() async {
    setState(() { cargando = true; log = "Descargando música de fondo... "; });
    try {
      String urlMusica = "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3"; // Pista de ejemplo
      final response = await http.get(Uri.parse(urlMusica));
      if (response.statusCode == 200) {
        String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
        if (selectedDirectory != null) {
          File musicaFile = File('$selectedDirectory/musica_fondo.mp3');
          await musicaFile.writeAsBytes(response.bodyBytes);
          setState(() { rutaMusicaSeleccionada = musicaFile.path; log = "Música descargada y lista."; });
        } else {
          setState(() { log = "Descarga de música cancelada."; });
        }
      } else {
        setState(() => log = "Error al descargar música: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => log = "Error de red al descargar música: $e");
    } finally {
      setState(() => cargando = false);
    }
  }

  Future<void> procesarIA() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) { setState(() => log = "❌ ERROR: Debes pegar tu API Key."); return; }
    setState(() => cargando = true);
    try {
      final model = GenerativeModel(model: 'gemini-3-flash-preview', apiKey: key);
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
        log = "¡GUION LISTO! Presiona RENDERIZAR.";
      });
    } catch (e) { setState(() => log = "Error IA: $e\n(Revisa el VPN de escritorio)"); }
    finally { setState(() => cargando = false); }
  }

  Future<void> renderizarVideo() async {
    if (fotos.isEmpty || clips.isEmpty) {
        setState(() => log = "Error: No hay fotos o guion para renderizar.");
        return;
    }
    if (rutaMusicaSeleccionada == null) {
        setState(() => log = "Error: Primero descarga la música con el botón.");
        return;
    }

    setState(() { cargando = true; log = "🎬 FABRICANDO MP4... Por favor espera."; });

    try {
      String carpetaBase = (await FilePicker.platform.getDirectoryPath()) ?? "."; // Pide dónde guardar
      if (carpetaBase == ".") {
          setState(() { cargando = false; log = "❌ Cancelaste la selección de carpeta."; });
          return;
      }
      String rutaSalida = "$carpetaBase\\Reel_IA_Final.mp4";
      String rutaGuion = "$carpetaBase\\guion_temp.txt";

      String contenidoGuion = "";
      for (var clip in clips) {
        String rutaFoto = fotos.firstWhere(
          (f) => f.name!.contains(clip.imageName.replaceAll("input_file_", "")),
          orElse: () => fotos.first
        ).path!;
        contenidoGuion += "file '$rutaFoto'\nduration ${clip.duration}\n";
      }
      
      await File(rutaGuion).writeAsString(contenidoGuion);

      final String comando = "-f concat -safe 0 -i \"$rutaGuion\" -i \"$rutaMusicaSeleccionada\" -vsync vfr -pix_fmt yuv420p -t 30 -y \"$rutaSalida\"";
      
      await FFmpegKit.execute(comando).then((session) async {
        final returnCode = await session.getReturnCode();
        setState(() {
          cargando = false;
          if (returnCode!.isValueSuccess()) {
            log = "✨ ¡VÍDEO CREADO! Búscalo en:\n$rutaSalida";
            File(rutaGuion).deleteSync(); // Borra el guion temporal
          } else {
            log = "❌ ERROR EN RENDERIZADO. Code: ${returnCode!.getValue()}";
          }
        });
      });

    } catch (e) {
      setState(() { cargando = false; log = "❌ Error de Archivos: $e"; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IA REEL STUDIO - FINAL BUILD')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              SizedBox(width: 450, child: TextField(controller: _apiKeyController, obscureText: true, decoration: const InputDecoration(labelText: '🔑 Pega aquí tu Nueva API Key', border: OutlineInputBorder()))),
              const SizedBox(height: 20),
              Text(log, textAlign: TextAlign.center, style: const TextStyle(color: Colors.cyanAccent)),
              const SizedBox(height: 20),
              if (!cargando) ...[
                ElevatedButton.icon(onPressed: seleccionar, icon: const Icon(Icons.add_a_photo), label: const Text("1. SUBIR FOTOS")),
                const SizedBox(height: 10),
                ElevatedButton.icon(onPressed: descargarMusica, icon: const Icon(Icons.music_note), label: const Text("2. DESCARGAR MÚSICA"), style: ElevatedButton.styleFrom(backgroundColor: Colors.purple)),
                const SizedBox(height: 10),
                if (fotos.isNotEmpty) ElevatedButton.icon(onPressed: procesarIA, icon: const Icon(Icons.psychology), style: ElevatedButton.styleFrom(backgroundColor: Colors.green), label: const Text("3. GENERAR GUION")),
                const SizedBox(height: 10),
                if (clips.isNotEmpty && rutaMusicaSeleccionada != null) ElevatedButton.icon(onPressed: renderizarVideo, icon: const Icon(Icons.movie), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue), label: const Text("4. RENDERIZAR VIDEO FINAL")),
                const SizedBox(height: 10),
                if (fotos.isNotEmpty || clips.isNotEmpty || rutaMusicaSeleccionada != null) ElevatedButton.icon(onPressed: limpiarTodo, icon: const Icon(Icons.clear), label: const Text("LIMPIAR TODO"), style: ElevatedButton.styleFrom(backgroundColor: Colors.red)),
              ],
              if (cargando) const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
