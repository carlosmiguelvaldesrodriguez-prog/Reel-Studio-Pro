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

// Importamos todos los módulos de arquitectura limpia
import 'features/video_editor/domain/models/clip.dart';
import 'features/video_editor/presentation/timeline_ui.dart';
import 'features/video_editor/data/ffmpeg_engine.dart';
import 'features/market_intelligence/data/market_agent.dart';
import 'features/music_jukebox/data/music_library.dart';

void main() => runApp(const MiEstudioApp());

class MiEstudioApp extends StatelessWidget {
  const MiEstudioApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, 
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.cyanAccent, // Color principal de la app
        hintColor: Colors.cyanAccent,    // Color de los hints en TextField
        appBarTheme: AppBarTheme(backgroundColor: Colors.grey.shade900, elevation: 0),
        scaffoldBackgroundColor: Colors.grey.shade900,
        textTheme: Theme.of(context).textTheme.apply(bodyColor: Colors.white),
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
  // --- CONTROLADORES DE ESTADO ---
  final TextEditingController _apiKeyController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer(); 
  final FFmpegBeatSyncEngine _ffmpegEngine = FFmpegBeatSyncEngine();
  
  List<PlatformFile> fotosRaw = []; // Archivos originales de FilePicker
  List<VideoClip> timelineClips = []; // Clips en el timeline para edición
  bool cargando = false;
  String log = "V2.0: Listo para iniciar operación.";
  
  String? rutaMusicaLocal; // Ruta del MP3 descargado
  
  // JUKEBOX AVANZADA
  String generoActivo = MusicLibrary.estilos.keys.first;
  int indiceCancion = 0;

  // CHAT CON AGENTE DE MERCADO
  final List<String> chatMessages = [];
  final TextEditingController _chatController = TextEditingController();


  // --- CICLO DE VIDA ---
  @override
  void dispose() {
    _audioPlayer.dispose(); 
    _apiKeyController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  // --- NAVEGACIÓN DE JUKEBOX ---
  void navegarCancion(int direccion) {
    setState(() {
      final canciones = MusicLibrary.estilos[generoActivo]!;
      indiceCancion = (indiceCancion + direccion) % canciones.length;
      if (indiceCancion < 0) indiceCancion = canciones.length - 1;
      _audioPlayer.stop(); // Detener cualquier pre-escucha activa
      log = "Pista seleccionada: ${canciones[indiceCancion]['nombre']}";
    });
  }

  // --- ACCIONES PRINCIPALES ---
  Future<void> preescuchar() async {
    await _audioPlayer.stop();
    final url = MusicLibrary.estilos[generoActivo]![indiceCancion]['url']!;
    await _audioPlayer.play(UrlSource(url));
    setState(() => log = "Escuchando: ${MusicLibrary.estilos[generoActivo]![indiceCancion]['nombre']}");
  }

  Future<void> descargarMusica() async {
    final cancion = MusicLibrary.estilos[generoActivo]![indiceCancion];
    await _audioPlayer.stop();
    setState(() { cargando = true; log = "Descargando audio oficial..."; });
    try {
      final response = await http.get(Uri.parse(cancion["url"]!));
      Directory tempDir = await getTemporaryDirectory();
      File f = File('${tempDir.path}\\${cancion["nombre"]!.replaceAll(' ', '_')}.mp3');
      await f.writeAsBytes(response.bodyBytes);
      setState(() { rutaMusicaLocal = f.path; log = "Música lista para procesar."; });
    } catch (e) { setState(() => log = "Error de descarga de música."); }
    finally { setState(() => cargando = false); }
  }

  Future<void> seleccionarFotos() async {
    var res = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
    if (res != null) {
      setState(() {
        fotosRaw = res.files;
        timelineClips = res.paths.map((p) => VideoClip(id: UniqueKey().toString(), imagePath: p!)).toList();
        log = "Fotos cargadas en el Timeline.";
      });
    }
  }

  void onTimelineOrderChanged(List<VideoClip> newOrder) {
    setState(() => timelineClips = newOrder);
    log = "Clips reordenados.";
  }

  void onTimelineTransitionChanged(VideoClip clip, String newTransition) {
    setState(() {
      final index = timelineClips.indexWhere((c) => c.id == clip.id);
      if (index != -1) timelineClips[index].transitionType = newTransition;
    });
    log = "Transición cambiada para ${clip.id}.";
  }

  void onTimelineDurationChanged(VideoClip clip, double newDuration) {
    setState(() {
      final index = timelineClips.indexWhere((c) => c.id == clip.id);
      if (index != -1) timelineClips[index].durationSeconds = newDuration;
    });
    log = "Duración cambiada para ${clip.id}.";
  }

  // --- LA IA (GEMINI 3 FLASH) ---
  Future<void> generarGuionConIA() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) { setState(() => log = "❌ ERROR: Pega la API Key."); return; }
    setState(() { cargando = true; log = "Gemini 3 analizando fotos y ritmo..."; });
    try {
      final model = GenerativeModel(model: 'gemini-3-flash-preview', apiKey: key);
      final images = <DataPart>[];
      for (var f in fotosRaw) {
        final bytes = await File(f.path!).readAsBytes();
        final mini = img.encodeJpg(img.copyResize(img.decodeImage(bytes)!, width: 400), quality: 60);
        images.add(DataPart('image/jpeg', Uint8List.fromList(mini)));
      }
      
      final infoMusica = MusicLibrary.estilos[generoActivo]![indiceCancion];
      final ritmo = infoMusica['bpm'];

      final prompt = TextPart('''
        Actúa como Director de Arte y Editor de Video.
        CONTEXTO MUSICAL: Género: $generoActivo, Ritmo: $ritmo.
        TAREA: Crea un Reel de 30s exactos con 10 escenas.
        
        REGLAS DE RITMO (BEAT-EDITING):
        1. Si el ritmo es "rápido": Clips de 1.5s a 2.5s. Transiciones dinámicas (wipeleft, pixelize).
        2. Si el ritmo es "lento": Clips de 3.5s a 4.5s. Transiciones suaves (fade).
        3. Si el ritmo es "medio": Clips de 2.5s a 3.5s. Mezcla variada (fade, wipeleft).
        
        RESPONDE SOLO JSON: {"timeline":[{"image_name":"foto_1","duration_sec":3.0,"transition":"fade"}]}
      ''');

      final resp = await model.generateContent([Content.multi([...images, prompt])]);
      final data = jsonDecode(resp.text!.replaceAll('```json', '').replaceAll('```', '').trim());
      
      // Actualizar los clips existentes con las sugerencias de la IA
      List<VideoClip> clipsSugeridos = (data['timeline'] as List).map((item) {
        final String imageNameFromIA = item['image_name'] ?? 'foto_1';
        // Buscamos una foto existente que contenga el nombre de la IA o usamos la primera
        final String path = fotosRaw.firstWhere(
          (f) => f.name!.contains(imageNameFromIA.replaceAll('foto_', '')), 
          orElse: () => fotosRaw.first
        ).path!;
        return VideoClip(
          id: UniqueKey().toString(),
          imagePath: path,
          durationSeconds: (item['duration_sec'] as num).toDouble(),
          transitionType: item['transition'] ?? 'fade',
        );
      }).toList();

      setState(() { timelineClips = clipsSugeridos; log = "Guion rítmico listo."; });

    } catch (e) { setState(() => log = "Error IA o red."); }
    finally { setState(() => cargando = false); }
  }


  Future<void> enviarMensajeChat() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) return;

    setState(() {
      chatMessages.add("Tú: ${_chatController.text}");
      log = "Enviando al Agente de Marketing...";
    });
    
    final promptUsuario = _chatController.text;
    _chatController.clear();

    final agent = MarketAgent(apiKey: key);
    final rec = await agent.getMarketRecommendation(promptUsuario); // Pasar la consulta del usuario
    setState(() {
      chatMessages.add("Agente: ${rec['nicho_recomendado']} - ${rec['justificacion_mercado']}");
      log = "Recomendación de mercado recibida.";
    });
  }


  Future<void> renderizarVideo() async {
    if (timelineClips.isEmpty || rutaMusicaLocal == null) { setState(() => log = "❌ Faltan recursos."); return; }
    String rutaFFmpeg = "${Directory.current.path}\\bin\\ffmpeg.exe";
    if (!File(rutaFFmpeg).existsSync()) { setState(() => log = "❌ No encuentro ffmpeg.exe"); return; }
    setState(() { cargando = true; log = "🎬 Aplicando transiciones rítmicas..."; });

    try {
      String? dir = await FilePicker.platform.getDirectoryPath();
      if (dir == null) { setState(() => cargando = false); return; }
      String salida = "$dir\\Reel_V20_${DateTime.now().millisecondsSinceEpoch}.mp4";
      List<String> args = [];
      String filter = "";
      for (int i = 0; i < timelineClips.length; i++) {
        String ruta = timelineClips[i].imagePath.replaceAll(r'\', '/');
        args.addAll(['-loop', '1', '-t', '${timelineClips[i].durationSeconds + 0.5}', '-i', ruta]);
        filter += "[$i:v]scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:-1:-1:color=black,format=yuv420p,setsar=1[v$i];";
      }
      args.addAll(['-i', rutaMusicaLocal!]);
      String ultima = "[v0]";
      double offset = timelineClips[0].durationSeconds - 0.5;
      for (int i = 1; i < timelineClips.length; i++) {
        String t = timelineClips[i].transitionType.toLowerCase();
        if (t == 'crossfade') t = 'fade';
        filter += "$ultima[v$i]xfade=transition=$t:duration=0.5:offset=$offset[f$i];";
        ultima = "[f$i]";
        offset += (timelineClips[i].durationSeconds - 0.5);
      }
      args.addAll(['-filter_complex', filter, '-map', ultima, '-map', '${timelineClips.length}:a', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-t', '30', '-y', salida]);
      ProcessResult res = await Process.run("${Directory.current.path}\\bin\\ffmpeg.exe", args);
      setState(() { cargando = false; log = res.exitCode == 0 ? "✨ ¡ÉXITO!\nVideo guardado en: $salida" : "❌ Error FFmpeg."; });
    } catch (e) { setState(() => log = "Error: $e"); }
  }
  @override
  Widget build(BuildContext context) {
    final cancionActual = MusicLibrary.estilos[generoActivo]![indiceCancion];
    return Scaffold(
      appBar: AppBar(title: const Text('IA REEL STUDIO PRO V2.0', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Row(
        children: [
          // Panel Izquierdo: Chat y Jukebox
          Container(
            width: 380,
            padding: const EdgeInsets.all(15),
            color: Colors.grey.shade900,
            child: Column(
              children: [
                TextField(controller: _apiKeyController, obscureText: true, decoration: const InputDecoration(labelText: 'Google API Key', border: OutlineInputBorder())),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    itemCount: chatMessages.length,
                    itemBuilder: (context, index) => Text(chatMessages[index], style: TextStyle(color: index % 2 == 0 ? Colors.cyanAccent : Colors.white70)),
                  ),
                ),
                TextField(
                  controller: _chatController,
                  decoration: InputDecoration(
                    hintText: "Pregunta al Agente de Marketing...",
                    suffixIcon: IconButton(icon: const Icon(Icons.send), onPressed: enviarMensajeChat),
                  ),
                  onSubmitted: (value) => enviarMensajeChat(),
                ),
                const SizedBox(height: 20),
                const Text("JUKEBOX DE MÚSICA", style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: generoActivo,
                  items: MusicLibrary.estilos.keys.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (v) => setState(() { generoActivo = v!; indiceCancion = 0; _audioPlayer.stop(); }),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(icon: const Icon(Icons.skip_previous), onPressed: () => navegarCancion(-1)),
                    Text(cancionActual['nombre']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.skip_next), onPressed: () => navegarCancion(1)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(icon: const Icon(Icons.play_arrow), onPressed: preescuchar),
                    IconButton(icon: const Icon(Icons.stop), onPressed: () => _audioPlayer.stop()),
                    ElevatedButton.icon(onPressed: descargarMusica, icon: const Icon(Icons.download), label: const Text("ELEGIR MÚSICA")),
                  ],
                ),
              ],
            ),
          ),
          // Panel Derecho: Timeline y Controles de Video
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: timelineClips.isNotEmpty
                      ? InteractiveTimeline(
                          clips: timelineClips,
                          onTimelineChanged: (newClips) => setState(() => timelineClips = newClips),
                          onDurationChanged: (clip, dur) {}, // Implementar control de duración en timeline_ui
                          onTransitionChanged: (clip, trans) => {}, // Implementar control de transición
                        )
                      : const Center(child: Text("Cargue fotos para ver el Timeline aquí.")),
                ),
                const SizedBox(height: 20),
                if (!cargando) Wrap(
                  spacing: 15, runSpacing: 15, alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(onPressed: seleccionarFotos, icon: const Icon(Icons.photo_library), label: const Text("CARGAR FOTOS")),
                    if (fotosRaw.isNotEmpty) ElevatedButton.icon(onPressed: generarGuionConIA, icon: const Icon(Icons.auto_awesome), style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade800), label: const Text("GENERAR GUION IA")),
                    if (timelineClips.isNotEmpty && rutaMusicaLocal != null) ElevatedButton.icon(onPressed: renderizarVideo, icon: const Icon(Icons.movie_creation), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800), label: const Text("RENDERIZAR REEL")),
                    ElevatedButton.icon(onPressed: limpiarTodo, icon: const Icon(Icons.clear), label: const Text("LIMPIAR"), style: ElevatedButton.styleFrom(backgroundColor: Colors.red)),
                  ],
                ),
                if (cargando) const Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()),
                const SizedBox(height: 20),
                Text(log, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
