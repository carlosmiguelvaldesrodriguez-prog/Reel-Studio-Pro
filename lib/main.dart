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

// Importamos tus nuevos módulos
import 'features/video_editor/domain/models/clip.dart';
import 'features/video_editor/presentation/timeline_ui.dart';
import 'features/video_editor/data/ffmpeg_engine.dart';
import 'features/market_intelligence/data/market_agent.dart';

void main() => runApp(const MiEstudioApp());

class MiEstudioApp extends StatelessWidget {
  const MiEstudioApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, 
      theme: ThemeData.dark().copyWith(primaryColor: Colors.cyanAccent),
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
  final TextEditingController _apiKeyController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<VideoClip> timelineClips = [];
  bool cargando = false;
  String log = "Sistema V2.0 Listo. Ingrese su API Key.";
  
  // BIBLIOTECA MUSICAL DE 5 ESTILOS
  final Map<String, List<String>> jukebox = {
    "Urbano": ["https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3", "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3"],
    "Boda/Gala": ["https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3", "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3"],
    "Infantil/Bebés": ["https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3"],
    "Quinceañeras": ["https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3"],
    "Corporativo": ["https://www.soundhelix.com/examples/mp3/SoundHelix-Song-10.mp3"],
  };
  
  String generoActivo = "Urbano";
  int cancionIndice = 0;
  String? rutaAudioFinal;

  // FUNCIÓN PARA EL CHAT DE SANTA CLARA
  Future<void> analizarMercado() async {
    if (_apiKeyController.text.isEmpty) return;
    setState(() { cargando = true; log = "Analizando competencia en Santa Clara, Cuba..."; });
    final agent = MarketAgent(apiKey: _apiKeyController.text);
    final rec = await agent.getMarketRecommendation();
    setState(() {
      cargando = false;
      log = "🎯 SUGERENCIA: ${rec['nicho']}\n${rec['explicacion']}";
    });
  }

  Future<void> seleccionarFotos() async {
    var res = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
    if (res != null) {
      setState(() {
        timelineClips = res.paths.map((p) => VideoClip(id: DateTime.now().toString() + p!, imagePath: p)).toList();
        log = "Fotos cargadas en el Timeline.";
      });
    }
  }

  Future<void> descargarElegida() async {
    await _audioPlayer.stop();
    setState(() => cargando = true);
    final res = await http.get(Uri.parse(jukebox[generoActivo]![cancionIndice]));
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/musica.mp3');
    await f.writeAsBytes(res.bodyBytes);
    setState(() { rutaAudioFinal = f.path; cargando = false; log = "Música lista para renderizar."; });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(title: const Text("REEL STUDIO PRO V2.0"), backgroundColor: Colors.transparent),
      body: Row(
        children: [
          // PANEL LATERAL: CHAT Y MÚSICA
          Container(
            width: 350,
            color: Colors.white10,
            padding: const EdgeInsets.all(15),
            child: Column(
              children: [
                TextField(controller: _apiKeyController, obscureText: true, decoration: const InputDecoration(labelText: "Google API Key")),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: analizarMercado, child: const Text("ANALIZAR SANTA CLARA")),
                const Divider(),
                const Text("JUKEBOX POR GÉNERO"),
                DropdownButton<String>(
                  value: generoActivo,
                  items: jukebox.keys.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (v) => setState(() { generoActivo = v!; cancionIndice = 0; }),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => cancionIndice = (cancionIndice - 1) % jukebox[generoActivo]!.length)),
                    IconButton(icon: const Icon(Icons.play_arrow), onPressed: () => _audioPlayer.play(UrlSource(jukebox[generoActivo]![cancionIndice]))),
                    IconButton(icon: const Icon(Icons.stop), onPressed: () => _audioPlayer.stop()),
                    IconButton(icon: const Icon(Icons.arrow_forward), onPressed: () => setState(() => cancionIndice = (cancionIndice + 1) % jukebox[generoActivo]!.length)),
                  ],
                ),
                ElevatedButton(onPressed: descargarElegida, child: const Text("ELEGIR ESTA CANCIÓN")),
                const Spacer(),
                Text(log, style: const TextStyle(fontSize: 11, color: Colors.cyanAccent)),
              ],
            ),
          ),
          // PANEL PRINCIPAL: TIMELINE Y VIDEO
          Expanded(
            child: Column(
              children: [
                const SizedBox(height: 20),
                if (timelineClips.isNotEmpty)
                  InteractiveTimeline(clips: timelineClips, onTimelineChanged: (newClips) => timelineClips = newClips),
                const SizedBox(height: 40),
                ElevatedButton.icon(onPressed: seleccionarFotos, icon: const Icon(Icons.add_a_photo), label: const Text("CARGAR FOTOS")),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.all(20)),
                  onPressed: () async {
                    setState(() => cargando = true);
                    final engine = FFmpegBeatSyncEngine();
                    await engine.renderEnterpriseReel(
                      clips: timelineClips, 
                      audioPath: rutaAudioFinal!, 
                      outputPath: "C:\\Users\\Public\\Reel_Final_V2.mp4", 
                      bpm: 120
                    );
                    setState(() { cargando = false; log = "¡VIDEO V2.0 CREADO!"; });
                  }, 
                  icon: const Icon(Icons.movie), 
                  label: const Text("RENDERIZAR REEL BEAT-SYNC")
                ),
                if (cargando) const CircularProgressIndicator(),
              ],
            ),
          )
        ],
      ),
    );
  }
}
