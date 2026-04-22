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
    return MaterialApp(
      debugShowCheckedModeBanner: false, 
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyan, brightness: Brightness.dark),
      ), 
      home: const PantallaPrincipal()
    );
  }
}

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});
  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}
class _PantallaPrincipalState extends State<PantallaPrincipal> {
  // VARIABLES DE ESTADO
  List<PlatformFile> fotos = [];
  List<VideoClip> clips = [];
  bool cargando = false;
  String log = "V1.2: Auditoría completa. Listo para operar.";
  final TextEditingController _apiKeyController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer(); 
  String? rutaMusicaLocal;

  // MATRIZ MUSICAL AVANZADA
  final Map<String, List<Map<String, String>>> biblioteca = {
    "Urbano/Moderno": [
      {"nombre": "Hip Hop Street", "url": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3", "bpm": "rápido"},
      {"nombre": "Urban Glitch", "url": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3", "bpm": "rápido"},
    ],
    "Cinematográfico/Boda": [
      {"nombre": "Epic Story", "url": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3", "bpm": "lento"},
      {"nombre": "Soft Piano Romance", "url": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3", "bpm": "lento"},
    ],
    "Pop/Publicidad": [
      {"nombre": "Pop Energetic", "url": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3", "bpm": "medio"},
      {"nombre": "Summer Vibes", "url": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-9.mp3", "bpm": "medio"},
    ]
  };

  String generoSeleccionado = "Urbano/Moderno";
  int indiceCancion = 0;

  @override
  void dispose() {
    _audioPlayer.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void navegarCancion(int direccion) {
    setState(() {
      indiceCancion = (indiceCancion + direccion) % biblioteca[generoSeleccionado]!.length;
      if (indiceCancion < 0) indiceCancion = biblioteca[generoSeleccionado]!.length - 1;
      _audioPlayer.stop();
      log = "Nueva pista seleccionada: ${biblioteca[generoSeleccionado]![indiceCancion]['nombre']}";
    });
  }

  Future<void> preescuchar() async {
    await _audioPlayer.stop();
    final url = biblioteca[generoSeleccionado]![indiceCancion]['url']!;
    await _audioPlayer.play(UrlSource(url));
    setState(() => log = "Reproduciendo: ${biblioteca[generoSeleccionado]![indiceCancion]['nombre']}");
  }

  Future<void> descargarMusica() async {
    await _audioPlayer.stop();
    setState(() { cargando = true; log = "Descargando para renderizado..."; });
    try {
      final url = biblioteca[generoSeleccionado]![indiceCancion]['url']!;
      final response = await http.get(Uri.parse(url));
      Directory tempDir = await getTemporaryDirectory();
      File f = File('${tempDir.path}\\musica_v12.mp3');
      await f.writeAsBytes(response.bodyBytes);
      setState(() { rutaMusicaLocal = f.path; log = "Audio listo para el video."; });
    } catch (e) { setState(() => log = "Error descarga audio."); }
    finally { setState(() => cargando = false); }
  }
  Future<void> seleccionar() async {
    FilePickerResult? res = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
    if (res != null) setState(() { fotos = res.files; clips = []; log = "Fotos cargadas."; });
  }

  void limpiarTodo() {
    setState(() { fotos = []; clips = []; rutaMusicaLocal = null; log = "App lista."; });
  }

  // EL CEREBRO: PROCESAMIENTO RÍTMICO
  Future<void> procesarIA() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) { setState(() => log = "❌ ERROR: Pega la API Key."); return; }
    setState(() { cargando = true; log = "IA analizando ritmo y fotos..."; });

    try {
      final model = GenerativeModel(model: 'gemini-3-flash-preview', apiKey: key);
      final images = <DataPart>[];
      
      // OPTIMIZACIÓN CELERON: Compresión por etapas con pausas
      for (var f in fotos) {
        final bytes = await File(f.path!).readAsBytes();
        final mini = img.encodeJpg(img.copyResize(img.decodeImage(bytes)!, width: 400), quality: 60);
        images.add(DataPart('image/jpeg', Uint8List.fromList(mini)));
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // EXTRACCIÓN DE METADATOS MUSICALES PARA LA IA
      final infoMusica = biblioteca[generoSeleccionado]![indiceCancion];
      final ritmo = infoMusica['bpm'];

      final prompt = TextPart('''
        Actúa como Director de Arte y Editor de Video.
        CONTEXTO MUSICAL: Género: $generoSeleccionado, Ritmo: $ritmo.
        TAREA: Crea un Reel de 30s exactos con 10 escenas.
        
        REGLAS DE RITMO (BEAT-EDITING):
        1. Si el ritmo es "rápido": Clips de 1.5s a 2.5s. Transiciones dinámicas (wipeleft, pixelize).
        2. Si el ritmo es "lento": Clips de 3.5s a 4.5s. Transiciones suaves (fade).
        3. Si el ritmo es "medio": Clips de 3.0s constantes. Mezcla variada.
        
        RESPONDE SOLO JSON: {"timeline":[{"image_name":"x","duration_sec":3.0,"transition":"fade"}]}
      ''');

      final resp = await model.generateContent([Content.multi([...images, prompt])]);
      final data = jsonDecode(resp.text!.replaceAll('```json', '').replaceAll('```', '').trim());
      
      setState(() { 
        clips = (data['timeline'] as List).map((i) => VideoClip.fromJson(i)).toList();
        log = "Guion rítmico listo. Estilo: $generoSeleccionado.";
      });
    } catch (e) { setState(() => log = "Error IA o red."); }
    finally { setState(() => cargando = false); }
  }
  // EL MÚSCULO: RENDERIZADO NATIVO CON XFADE
  Future<void> renderizarVideo() async {
    if (fotos.isEmpty || clips.isEmpty || rutaMusicaLocal == null) {
      setState(() => log = "❌ Faltan recursos para el video."); return;
    }
    
    String rutaFFmpeg = "${Directory.current.path}\\bin\\ffmpeg.exe";
    if (!File(rutaFFmpeg).existsSync()) {
      setState(() => log = "❌ ERROR: No está ffmpeg.exe en la carpeta bin."); return;
    }

    setState(() { cargando = true; log = "🎬 Aplicando transiciones rítmicas..."; });

    try {
      String? dir = await FilePicker.platform.getDirectoryPath();
      if (dir == null) { setState(() => cargando = false); return; }
      String salida = "$dir\\Reel_V12_${DateTime.now().millisecondsSinceEpoch}.mp4";
      
      List<String> args = [];
      String filter = "";
      
      // 1. Inputs y Escalado
      for (int i = 0; i < clips.length; i++) {
        String ruta = fotos[i % fotos.length].path!.replaceAll(r'\', '/');
        args.addAll(['-loop', '1', '-t', '${clips[i].duration + 0.5}', '-i', ruta]);
        filter += "[$i:v]scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:-1:-1:color=black,format=yuv420p,setsar=1[v$i];";
      }
      
      // 2. Audio
      args.addAll(['-i', rutaMusicaLocal!]);
      
      // 3. Cadena de Transiciones
      String last = "[v0]";
      double offset = clips[0].duration - 0.5;
      for (int i = 1; i < clips.length; i++) {
        String t = clips[i].transition.toLowerCase();
        if (t == 'crossfade') t = 'fade';
        filter += "$last[v$i]xfade=transition=$t:duration=0.5:offset=$offset[f$i];";
        last = "[f$i]";
        offset += (clips[i].duration - 0.5);
      }

      args.addAll(['-filter_complex', filter, '-map', last, '-map', '${clips.length}:a', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-t', '30', '-y', salida]);

      ProcessResult res = await Process.run(rutaFFmpeg, args);
      setState(() { 
        cargando = false; 
        log = res.exitCode == 0 ? "✨ ¡VIDEO CREADO!\nUbicación: $salida" : "❌ Error FFmpeg."; 
      });
    } catch (e) { setState(() { cargando = false; log = "Error de Sistema."; }); }
  }

  @override
  Widget build(BuildContext context) {
    final cancionActual = biblioteca[generoSeleccionado]![indiceCancion];
    
    return Scaffold(
      appBar: AppBar(title: const Text('IA REEL STUDIO PRO V1.2')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),
          child: Column(
            children: [
              SizedBox(width: 400, child: TextField(controller: _apiKeyController, obscureText: true, decoration: const InputDecoration(labelText: '🔑 API Key', border: OutlineInputBorder()))),
              const SizedBox(height: 25),
              
              // SELECTOR DE GÉNERO
              DropdownButton<String>(
                value: generoSeleccionado,
                onChanged: (val) => setState(() { generoSeleccionado = val!; indiceCancion = 0; }),
                items: biblioteca.keys.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
              ),
              
              // REPRODUCTOR JUKEBOX
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(icon: const Icon(Icons.skip_previous), onPressed: () => navegarCancion(-1)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)),
                    child: Text(cancionActual['nombre']!, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                  ),
                  IconButton(icon: const Icon(Icons.skip_next), onPressed: () => navegarCancion(1)),
                ],
              ),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(onPressed: preescuchar, icon: const Icon(Icons.play_arrow), label: const Text("ESCUCHAR")),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(onPressed: descargarMusica, icon: const Icon(Icons.download), label: const Text("ELEGIR PARA VIDEO"), style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade900)),
                ],
              ),

              const Divider(height: 50),
              
              if (!cargando) Wrap(
                spacing: 15, runSpacing: 15, alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(onPressed: seleccionar, icon: const Icon(Icons.photo_library), label: const Text("1. SUBIR FOTOS")),
                  if (fotos.isNotEmpty) ElevatedButton.icon(onPressed: procesarIA, icon: const Icon(Icons.auto_awesome), style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade800), label: const Text("2. GUION RÍTMICO")),
                  if (clips.isNotEmpty && rutaMusicaLocal != null) ElevatedButton.icon(onPressed: renderizarVideo, icon: const Icon(Icons.movie_filter), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800), label: const Text("3. RENDERIZAR REEL")),
                  if (fotos.isNotEmpty) IconButton(onPressed: limpiarTodo, icon: const Icon(Icons.refresh, color: Colors.redAccent)),
                ],
              ),

              if (cargando) const Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()),
              const SizedBox(height: 20),
              Text(log, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
