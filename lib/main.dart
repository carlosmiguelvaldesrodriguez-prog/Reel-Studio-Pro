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
    imageName: json['image_name'] ?? "foto.jpg",
    duration: (json['duration_sec'] ?? 3.0).toDouble(),
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
  String log = "V1.3: Transiciones Dinámicas listas.";
  final TextEditingController _apiKeyController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer(); 
  String? rutaMusicaLocal;

  final Map<String, List<Map<String, String>>> jukebox = {
    "Urbano/Rápido": [{"nombre": "Hip Hop Street", "url": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3", "bpm": "rápido"}],
    "Cinematográfico/Lento": [{"nombre": "Epic Story", "url": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3", "bpm": "lento"}],
    "Pop/Enérgico": [{"nombre": "Summer Pop", "url": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3", "bpm": "medio"}],
  };
  String generoSeleccionado = "Urbano/Rápido";
  int indiceCancion = 0;

  @override
  void dispose() {
    _audioPlayer.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void navegarCancion(int dir) {
    setState(() {
      final canciones = jukebox[generoSeleccionado]!;
      indiceCancion = (indiceCancion + dir) % canciones.length;
      if (indiceCancion < 0) indiceCancion = canciones.length - 1;
      _audioPlayer.stop();
      log = "Pista seleccionada: ${canciones[indiceCancion]['nombre']}";
    });
  }

  Future<void> preescuchar() async {
    await _audioPlayer.stop();
    final url = jukebox[generoSeleccionado]![indiceCancion]['url']!;
    await _audioPlayer.play(UrlSource(url));
    setState(() => log = "Reproduciendo...");
  }

  Future<void> descargarMusica() async {
    if (jukebox[generoSeleccionado]!.isEmpty) return;
    await _audioPlayer.stop();
    setState(() { cargando = true; log = "Descargando audio..."; });
    try {
      final response = await http.get(Uri.parse(jukebox[generoSeleccionado]![indiceCancion]['url']!));
      Directory tempDir = await getTemporaryDirectory();
      File f = File('${tempDir.path}\\musica_v13.mp3');
      await f.writeAsBytes(response.bodyBytes);
      setState(() { rutaMusicaLocal = f.path; log = "Audio listo."; });
    } catch (e) { setState(() => log = "Error de descarga."); }
    finally { setState(() => cargando = false); }
  }

  Future<void> seleccionar() async {
    var res = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
    if (res != null) setState(() { fotos = res.files; clips = []; log = "Fotos cargadas."; });
  }

  Future<void> procesarIA() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) { setState(() => log = "❌ Pega la API Key."); return; }
    setState(() { cargando = true; log = "IA analizando ritmo..."; });
    try {
      final model = GenerativeModel(model: 'gemini-3-flash-preview', apiKey: key);
      final images = <DataPart>[];
      for (var f in fotos) {
        final bytes = await File(f.path!).readAsBytes();
        final mini = img.encodeJpg(img.copyResize(img.decodeImage(bytes)!, width: 400), quality: 60);
        images.add(DataPart('image/jpeg', Uint8List.fromList(mini)));
      }
      final ritmo = jukebox[generoSeleccionado]![indiceCancion]['bpm'];
      final prompt = TextPart('Director: Crea Reel 30s. 10 escenas. Ritmo: $ritmo. Si es rápido, clips de 1.5s-2.5s y transiciones wipe/pixelize. Si es lento, clips de 3.5s-4.5s y transiciones fade. JSON: {"timeline":[{"image_name":"foto_1","duration_sec":3.0,"transition":"fade"}]}');
      final resp = await model.generateContent([Content.multi([...images, prompt])]);
      final data = jsonDecode(resp.text!.replaceAll('```json', '').replaceAll('```', '').trim());
      setState(() { clips = (data['timeline'] as List).map((i) => VideoClip.fromJson(i)).toList(); log = "Guion rítmico listo."; });
    } catch (e) { setState(() => log = "Error IA o VPN."); }
    finally { setState(() => cargando = false); }
  }
  Future<void> renderizarVideo() async {
    if (fotos.isEmpty || clips.isEmpty || rutaMusicaLocal == null) {
      setState(() => log = "❌ Faltan recursos."); return;
    }
    String rutaFFmpeg = "${Directory.current.path}\\bin\\ffmpeg.exe";
    if (!File(rutaFFmpeg).existsSync()) {
      setState(() => log = "❌ No encuentro ffmpeg.exe"); return;
    }
    setState(() { cargando = true; log = "🎬 Aplicando transiciones dinámicas..."; });
    try {
      String? dir = await FilePicker.platform.getDirectoryPath();
      if (dir == null) { setState(() => cargando = false); return; }
      String salida = "$dir\\Reel_V13_${DateTime.now().millisecondsSinceEpoch}.mp4";
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
        // --- LA CORRECCIÓN CRÍTICA ESTÁ AQUÍ ---
        String trans = clips[i].transition.toLowerCase(); // Leemos la transición que dijo la IA
        List<String> validas = ['fade', 'wipeleft', 'wiperight', 'slideup', 'slidedown', 'pixelize'];
        if (trans == 'crossfade' || trans == 'fade_black') trans = 'fade';
        if (!validas.contains(trans)) trans = 'fade'; // Si la IA inventa, usamos "fade" por seguridad

        filters += "$ultima[v$i]xfade=transition=$trans:duration=0.5:offset=$offset[f$i];"; // La usamos en el comando
        ultima = "[f$i]";
        offset += (clips[i].duration - 0.5);
      }
      args.addAll(['-filter_complex', filters, '-map', ultima, '-map', '${clips.length}:a', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-t', '30', '-y', salida]);
      ProcessResult res = await Process.run(rutaFFmpeg, args);
      setState(() { cargando = false; log = res.exitCode == 0 ? "✨ ¡ÉXITO!\nVideo guardado en: $salida" : "❌ Error FFmpeg."; });
    } catch (e) { setState(() { cargando = false; log = "Error de Sistema."; }); }
  }

  @override
  Widget build(BuildContext context) {
    final cancionActual = jukebox[generoSeleccionado]![indiceCancion];
    return Scaffold(
      appBar: AppBar(title: const Text('IA REEL STUDIO PRO V1.3')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SizedBox(width: 450, child: TextField(controller: _apiKeyController, obscureText: true, decoration: const InputDecoration(labelText: '🔑 API Key', border: OutlineInputBorder()))),
            const SizedBox(height: 20),
            Text(log, textAlign: TextAlign.center, style: const TextStyle(fontStyle: FontStyle.italic)),
            const Divider(height: 30),
            
            // Jukebox UI
            const Text("1. Elige tu música:", style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: generoSeleccionado,
              onChanged: (val) => setState(() { generoSeleccionado = val!; indiceCancion = 0; }),
              items: jukebox.keys.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(icon: const Icon(Icons.skip_previous), onPressed: () => navegarCancion(-1)),
              Text(cancionActual['nombre']!),
              IconButton(icon: const Icon(Icons.skip_next), onPressed: () => navegarCancion(1)),
            ]),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ElevatedButton.icon(onPressed: preescuchar, icon: const Icon(Icons.play_arrow), label: const Text("Escuchar")),
              const SizedBox(width: 10),
              ElevatedButton.icon(onPressed: descargarMusica, icon: const Icon(Icons.download), label: const Text("Elegir"), style: ElevatedButton.styleFrom(backgroundColor: Colors.purple)),
            ]),
            const Divider(height: 30),

            if (!cargando) ...[
              const Text("2. Sube tus fotos:", style: TextStyle(fontWeight: FontWeight.bold)),
              ElevatedButton.icon(onPressed: seleccionar, icon: const Icon(Icons.photo_library), label: const Text("Seleccionar Fotos")),
              const SizedBox(height: 20),
              if (fotos.isNotEmpty) ...[
                const Text("3. Genera el guion y renderiza:", style: TextStyle(fontWeight: FontWeight.bold)),
                ElevatedButton.icon(onPressed: procesarIA, icon: const Icon(Icons.psychology), style: ElevatedButton.styleFrom(backgroundColor: Colors.green), label: const Text("Generar Guion IA")),
                const SizedBox(height: 10),
                if (clips.isNotEmpty) ElevatedButton.icon(onPressed: renderizarVideo, icon: const Icon(Icons.movie_creation), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue), label: const Text("Renderizar Reel Final")),
              ],
            ],
            if (cargando) const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
