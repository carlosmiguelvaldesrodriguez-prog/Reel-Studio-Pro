import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart'; 
import 'package:google_generative_ai/google_generative_ai.dart'; 
import 'package:image/image.dart' as img; 
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
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
    transition: json['transition'] ?? 'fade'
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
  String log = "V1.1: Configura tu API Key y elige la música.";
  final TextEditingController _apiKeyController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer(); 
  String? rutaMusicaLocal;

  final List<Map<String, String>> jukebox = [
    {"nombre": "Urbana & Rítmica", "url": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3"},
    {"nombre": "Épica Cinematográfica", "url": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3"},
    {"nombre": "Lounge Relajante", "url": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3"},
    {"nombre": "Pop Enérgico", "url": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3"},
  ];
  Map<String, String>? cancionSeleccionada;

  @override
  void dispose() {
    _audioPlayer.dispose(); // Cierre seguro de la app
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> preescuchar(String url) async {
    await _audioPlayer.stop();
    await _audioPlayer.play(UrlSource(url));
    setState(() => log = "Escuchando vista previa...");
  }

  Future<void> descargarMusica() async {
    if (cancionSeleccionada == null) { setState(() => log = "❌ Elige una canción primero."); return; }
    await _audioPlayer.stop();
    setState(() { cargando = true; log = "Descargando audio oficial..."; });
    try {
      final response = await http.get(Uri.parse(cancionSeleccionada!["url"]!));
      Directory tempDir = await getTemporaryDirectory();
      File f = File('${tempDir.path}\\musica_final.mp3');
      await f.writeAsBytes(response.bodyBytes);
      setState(() { rutaMusicaLocal = f.path; log = "Música lista para el video."; });
    } catch (e) { setState(() => log = "Error de red al descargar música."); }
    finally { setState(() => cargando = false); }
  }

  Future<void> seleccionar() async {
    var res = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
    if (res != null) setState(() { fotos = res.files; clips = []; log = "Fotos cargadas con éxito."; });
  }

  Future<void> procesarIA() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) { setState(() => log = "❌ ERROR: Pega la API Key."); return; }
    setState(() { cargando = true; log = "Gemini 3 analizando narrativa..."; });
    try {
      final model = GenerativeModel(model: 'gemini-3-flash-preview', apiKey: key);
      final images = <DataPart>[];
      for (var f in fotos) {
        final bytes = await File(f.path!).readAsBytes();
        final mini = img.encodeJpg(img.copyResize(img.decodeImage(bytes)!, width: 400), quality: 60);
        images.add(DataPart('image/jpeg', Uint8List.fromList(mini)));
      }
      final prompt = TextPart('Director Pro: Crea Reel 30s. 10 escenas. Transiciones dinámicas. JSON: {"timeline":[{"image_name":"x","duration_sec":3.0, "transition":"fade"}]}');
      final resp = await model.generateContent([Content.multi([...images, prompt])]);
      final data = jsonDecode(resp.text!.replaceAll('```json', '').replaceAll('```', '').trim());
      setState(() { clips = (data['timeline'] as List).map((i) => VideoClip.fromJson(i)).toList(); log = "Guion listo. ¡A renderizar!"; });
    } catch (e) { setState(() => log = "Error de IA o VPN."); }
    finally { setState(() => cargando = false); }
  }
  Future<void> renderizarVideo() async {
    if (fotos.isEmpty || clips.isEmpty || rutaMusicaLocal == null) {
      setState(() => log = "❌ Error: Faltan recursos (fotos, guion o música)."); return;
    }
    String rutaFFmpeg = "${Directory.current.path}\\bin\\ffmpeg.exe";
    if (!File(rutaFFmpeg).existsSync()) {
      setState(() => log = "❌ ERROR: No encuentro ffmpeg.exe en la carpeta bin."); return;
    }
    setState(() { cargando = true; log = "🎬 Renderizando Reel publicitario..."; });
    try {
      String? dir = await FilePicker.platform.getDirectoryPath();
      if (dir == null) { setState(() => cargando = false); return; }
      String salida = "$dir\\Reel_Estudio_Pro_${DateTime.now().millisecondsSinceEpoch}.mp4";
      List<String> args = [];
      String filters = "";
      for (int i = 0; i < clips.length; i++) {
        String ruta = fotos[i % fotos.length].path!.replaceAll(r'\', '/');
        args.addAll(['-loop', '1', '-t', '${clips[i].duration + 0.5}', '-i', ruta]);
        filters += "[$i:v]scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:-1:-1:color=black,format=yuv420p,setsar=1[v$i];";
      }
      args.addAll(['-i', rutaMusicaLocal!]);
      String ultima = "[v0]";
      double offset = clips[0].duration - 0.5;
      for (int i = 1; i < clips.length; i++) {
        filters += "$ultima[v$i]xfade=transition=fade:duration=0.5:offset=$offset[f$i];";
        ultima = "[f$i]";
        offset += (clips[i].duration - 0.5);
      }
      args.addAll(['-filter_complex', filters, '-map', ultima, '-map', '${clips.length}:a', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-t', '30', '-y', salida]);
      ProcessResult res = await Process.run(rutaFFmpeg, args);
      setState(() { cargando = false; log = res.exitCode == 0 ? "✨ ¡ÉXITO! Video guardado en:\n$salida" : "❌ Error en motor de video."; });
    } catch (e) { setState(() { cargando = false; log = "Error de Sistema: $e"; }); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IA REEL STUDIO PRO V1.1')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              SizedBox(width: 450, child: TextField(controller: _apiKeyController, obscureText: true, decoration: const InputDecoration(labelText: '🔑 Pega tu Google API Key', border: OutlineInputBorder()))),
              const SizedBox(height: 20),
              const Text("🎵 SELECTOR DE MÚSICA PUBLICITARIA", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
              const SizedBox(height: 10),
              for (var c in jukebox)
                ListTile(
                  title: Text(c["nombre"]!),
                  leading: Radio<Map<String, String>>(
                    value: c, groupValue: cancionSeleccionada,
                    onChanged: (val) => setState(() => cancionSeleccionada = val),
                  ),
                  trailing: IconButton(icon: const Icon(Icons.play_circle_fill, color: Colors.purpleAccent), onPressed: () => preescuchar(c["url"]!)),
                ),
              ElevatedButton.icon(onPressed: descargarMusica, icon: const Icon(Icons.download), label: const Text("DESCARGAR MÚSICA")),
              const Divider(height: 50),
              if (!cargando) Wrap(
                spacing: 20, runSpacing: 20, alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(onPressed: seleccionar, icon: const Icon(Icons.add_photo_alternate), label: const Text("1. FOTOS")),
                  if (fotos.isNotEmpty) ElevatedButton.icon(onPressed: procesarIA, icon: const Icon(Icons.psychology), style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade800), label: const Text("2. GUION IA")),
                  if (clips.isNotEmpty && rutaMusicaLocal != null) ElevatedButton.icon(onPressed: renderizarVideo, icon: const Icon(Icons.movie_creation), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800), label: const Text("3. RENDERIZAR REEL")),
                ],
              ),
              if (cargando) const Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()),
              const SizedBox(height: 20),
              Text(log, textAlign: TextAlign.center, style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
          ),
        ),
      ),
    );
  }
}
