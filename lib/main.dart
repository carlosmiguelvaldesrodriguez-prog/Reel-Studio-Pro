import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart'; 
import 'package:google_generative_ai/google_generative_ai.dart'; 
import 'package:image/image.dart' as img; 
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';


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
  String? rutaMusicaSeleccionada;

  Future<void> seleccionar() async {
    FilePickerResult? res = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
    if (res != null) setState(() { fotos = res.files; clips = []; log = "${res.files.length} fotos cargadas."; });
  }

  void limpiarTodo() {
    setState(() { fotos = []; clips = []; rutaMusicaSeleccionada = null; log = "App reiniciada."; });
  }

  Future<void> descargarMusica() async {
    setState(() { cargando = true; log = "Descargando música de fondo..."; });
    try {
      String urlMusica = "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3";
      final response = await http.get(Uri.parse(urlMusica));
      if (response.statusCode == 200) {
        String? dir = await FilePicker.platform.getDirectoryPath();
        if (dir != null) {
          File musicaFile = File('$dir\\musica_fondo.mp3');
          await musicaFile.writeAsBytes(response.bodyBytes);
          setState(() { rutaMusicaSeleccionada = musicaFile.path; log = "Música guardada en: $dir"; });
        } else {
          setState(() => log = "Descarga cancelada.");
        }
      }
    } catch (e) { setState(() => log = "Error de red: $e"); } 
    finally { setState(() => cargando = false); }
  }

  Future<void> procesarIA() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) { setState(() => log = "❌ ERROR: Pega la API Key."); return; }
    setState(() => cargando = true);
    try {
      // AQUÍ ESTÁ EL MODELO CORRECTO: GEMINI 3 FLASH PREVIEW
      final model = GenerativeModel(model: 'gemini-3-flash-preview', apiKey: key);
      final images = <DataPart>[];
      for (var f in fotos) {
        final bytes = await File(f.path!).readAsBytes();
        final mini = img.encodeJpg(img.copyResize(img.decodeImage(bytes)!, width: 400), quality: 60);
        images.add(DataPart('image/jpeg', Uint8List.fromList(mini)));
      }
      final prompt = TextPart('Director de Arte: Crea Reel de 30s. 10 escenas de ~3s. Alterna transiciones: crossfade, fade_black, wipeleft. JSON: {"timeline":[{"image_name":"x","duration_sec":3.0, "transition":"crossfade"}]}');
      final resp = await model.generateContent([Content.multi([...images, prompt])]);
      final data = jsonDecode(resp.text!.replaceAll('```json', '').replaceAll('```', '').trim());
      setState(() { 
        clips = (data['timeline'] as List).map((i) => VideoClip.fromJson(i)).toList();
        log = "¡GUION LISTO! Presiona RENDERIZAR.";
      });
    } catch (e) { setState(() => log = "Error IA: $e\n(Revisa el VPN)"); }
    finally { setState(() => cargando = false); }
  }
   // --- NUEVA VERSIÓN: EL MÚSCULO NATIVO DE WINDOWS ---
  Future<void> renderizarVideo() async {
    if (fotos.isEmpty || clips.isEmpty || rutaMusicaSeleccionada == null) {
        setState(() => log = "❌ Faltan fotos, guion o descargar la música."); return;
    }
    setState(() { cargando = true; log = "🎬 INICIANDO MOTOR NATIVO FFMPEG..."; });

    try {
      String carpetaBase = (await FilePicker.platform.getDirectoryPath()) ?? ".";
      if (carpetaBase == ".") { setState(() { cargando = false; log = "❌ Cancelaste la selección de carpeta."; }); return; }
      
      String rutaSalida = "$carpetaBase\\Reel_IA_Final.mp4";
      String rutaGuion = "$carpetaBase\\guion_temp.txt";
      String contenidoGuion = "";
      
      for (var clip in clips) {
        String rutaFoto = fotos.firstWhere((f) => f.name.contains(clip.imageName.replaceAll("input_file_", "")), orElse: () => fotos.first).path!;
        // Limpiamos la ruta por si tiene barras raras
        rutaFoto = rutaFoto.replaceAll(r'\', '/');
        contenidoGuion += "file '$rutaFoto'\nduration ${clip.duration}\n";
      }
      await File(rutaGuion).writeAsString(contenidoGuion);

      // Buscamos ffmpeg.exe en la carpeta 'bin' al lado de nuestra app
      String rutaFFmpeg = "${Directory.current.path}\\bin\\ffmpeg.exe";

      // Ejecutamos el comando directamente en el sistema operativo Windows
      ProcessResult resultado = await Process.run(rutaFFmpeg, [
        '-f', 'concat', 
        '-safe', '0', 
        '-i', rutaGuion, 
        '-i', rutaMusicaSeleccionada!, 
        '-vsync', 'vfr', 
        '-pix_fmt', 'yuv420p', 
        '-t', '30', 
        '-y', 
        rutaSalida
      ]);

      setState(() {
        cargando = false;
        if (resultado.exitCode == 0) {
          log = "✨ ¡ÉXITO TOTAL! Video guardado en:\n$rutaSalida";
          if (File(rutaGuion).existsSync()) File(rutaGuion).deleteSync(); 
        } else { 
          log = "❌ ERROR DE WINDOWS.\nRevisa que la carpeta 'bin' con ffmpeg.exe esté junto a tu aplicación."; 
        }
      });
    } catch (e) { 
      setState(() { cargando = false; log = "❌ Error Crítico del Sistema: $e"; }); 
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
              SizedBox(width: 450, child: TextField(controller: _apiKeyController, obscureText: true, decoration: const InputDecoration(labelText: '🔑 Pega aquí tu API Key', border: OutlineInputBorder()))),
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
                if (clips.isNotEmpty && rutaMusicaSeleccionada != null) ElevatedButton.icon(onPressed: renderizarVideo, icon: const Icon(Icons.movie), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue), label: const Text("4. RENDERIZAR MP4")),
                const SizedBox(height: 10),
                if (fotos.isNotEmpty || clips.isNotEmpty) ElevatedButton.icon(onPressed: limpiarTodo, icon: const Icon(Icons.clear), label: const Text("LIMPIAR TODO"), style: ElevatedButton.styleFrom(backgroundColor: Colors.red)),
              ],
              if (cargando) const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
