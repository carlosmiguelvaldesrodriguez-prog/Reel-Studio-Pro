import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart'; 
import 'package:google_generative_ai/google_generative_ai.dart'; 
import 'package:image/image.dart' as img; 
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'dart:io';

void main() => runApp(const MiEstudioApp());

// --- CLASE DEL TRADUCTOR ---
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
    return MaterialApp(
      debugShowCheckedModeBanner: false, 
      theme: ThemeData.dark(), 
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
  List<PlatformFile> fotos = [];
  List<VideoClip> clips = [];
  bool cargando = false;
  String log = "Pega tu API Key, enciende tu VPN y sube tus fotos.";
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
        Directory tempDir = await getTemporaryDirectory();
        File musicaFile = File('${tempDir.path}\\musica_fondo.mp3');
        await musicaFile.writeAsBytes(response.bodyBytes);
        setState(() { rutaMusicaSeleccionada = musicaFile.path; log = "Música descargada con éxito."; });
      } else {
        setState(() => log = "Error al descargar música.");
      }
    } catch (e) { setState(() => log = "Error de red: $e"); } 
    finally { setState(() => cargando = false); }
  }

  Future<void> procesarIA() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) { setState(() => log = "❌ ERROR: Pega la API Key."); return; }
    setState(() => cargando = true);
    try {
      // MOTOR CONFIRMADO: GEMINI 3 FLASH
      final model = GenerativeModel(model: 'gemini-3-flash-preview', apiKey: key);
      final images = <DataPart>[];
      for (var f in fotos) {
        final bytes = await File(f.path!).readAsBytes();
        final mini = img.encodeJpg(img.copyResize(img.decodeImage(bytes)!, width: 400), quality: 60);
        images.add(DataPart('image/jpeg', Uint8List.fromList(mini)));
      }
      final prompt = TextPart('Director de Arte: Crea Reel 30s. 10 escenas de ~3s. Alterna transiciones: fade, wipeleft, wiperight, pixelize. JSON: {"timeline":[{"image_name":"x","duration_sec":3.0, "transition":"fade"}]}');
      final resp = await model.generateContent([Content.multi([...images, prompt])]);
      final data = jsonDecode(resp.text!.replaceAll('```json', '').replaceAll('```', '').trim());
      setState(() { 
        clips = (data['timeline'] as List).map((i) => VideoClip.fromJson(i)).toList();
        log = "¡GUION LISTO! Presiona RENDERIZAR.";
      });
    } catch (e) { setState(() => log = "Error IA: $e\n(Revisa el VPN)"); }
    finally { setState(() => cargando = false); }
  }
  Future<void> renderizarVideo() async {
    if (fotos.isEmpty || clips.isEmpty || rutaMusicaSeleccionada == null) {
        setState(() => log = "❌ Faltan fotos, guion o descargar la música."); return;
    }
    
    // Verificación de seguridad de FFmpeg
    String rutaFFmpeg = "${Directory.current.path}\\bin\\ffmpeg.exe";
    if (!File(rutaFFmpeg).existsSync()) {
      setState(() => log = "❌ ERROR: No encuentro ffmpeg.exe.\nAsegúrate de haber copiado la carpeta 'bin' al lado de esta aplicación.");
      return;
    }

    setState(() { cargando = true; log = "🎬 MATEMÁTICA VISUAL EN CURSO... Calculando transiciones."; });

    try {
      String carpetaBase = (await FilePicker.platform.getDirectoryPath()) ?? ".";
      if (carpetaBase == ".") { setState(() { cargando = false; log = "❌ Cancelaste."; }); return; }
      
      String rutaSalida = "$carpetaBase\\Reel_IA_Final.mp4";
      List<String> argsFFmpeg = [];
      String filterComplex = "";
      
      for (int i = 0; i < clips.length; i++) {
        String nombreBuscado = clips[i].imageName.replaceAll("input_file_", "");
        String rutaFoto = fotos.firstWhere((f) => f.name.contains(nombreBuscado), orElse: () => fotos.first).path!;
        rutaFoto = rutaFoto.replaceAll(r'\', '/'); 
        
        double duracionReal = clips[i].duration + 0.5;
        argsFFmpeg.addAll(['-loop', '1', '-t', '$duracionReal', '-i', rutaFoto]);
        filterComplex += "[$i:v]scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:-1:-1:color=black,format=yuv420p,setsar=1[v$i];";
      }

      argsFFmpeg.addAll(['-i', rutaMusicaSeleccionada!]);
      int indiceAudio = clips.length; 

      String ultimaSalida = "[v0]";
      double offsetActual = clips[0].duration - 0.5; 
      if (offsetActual < 0) offsetActual = 0;

      for (int i = 1; i < clips.length; i++) {
        String trans = clips[i].transition.toLowerCase();
        List<String> validas = ['fade', 'wipeleft', 'wiperight', 'slideup', 'slidedown', 'pixelize'];
        if (trans == 'crossfade' || trans == 'fade_black') trans = 'fade';
        if (!validas.contains(trans)) trans = 'fade';

        filterComplex += "$ultimaSalida[v$i]xfade=transition=$trans:duration=0.5:offset=$offsetActual[f$i];";
        ultimaSalida = "[f$i]";
        offsetActual += (clips[i].duration - 0.5); 
      }

      argsFFmpeg.addAll([
        '-filter_complex', filterComplex,
        '-map', ultimaSalida,
        '-map', '$indiceAudio:a',
        '-c:v', 'libx264',
        '-pix_fmt', 'yuv420p',
        '-t', '30', 
        '-y',
        rutaSalida
      ]);

      setState(() => log = "🔥 RENDERIZANDO... Tu CPU está uniendo los efectos.");

      ProcessResult resultado = await Process.run(rutaFFmpeg, argsFFmpeg);

      setState(() {
        cargando = false;
        if (resultado.exitCode == 0) {
          log = "✨ ¡ÉXITO MAGISTRAL! Reel guardado en:\n$rutaSalida";
        } else { 
          log = "❌ ERROR INTERNO FFmpeg.\nDetalle: ${resultado.stderr}"; 
        }
      });
    } catch (e) { 
      setState(() { cargando = false; log = "❌ Error del Sistema: $e"; }); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IA REEL STUDIO - PRO VERSION')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              SizedBox(width: 450, child: TextField(controller: _apiKeyController, obscureText: true, decoration: const InputDecoration(labelText: '🔑 Pega tu API Key', border: OutlineInputBorder()))),
              const SizedBox(height: 20),
              Container(padding: const EdgeInsets.all(10), color: Colors.black26, child: Text(log, textAlign: TextAlign.center, style: const TextStyle(color: Colors.cyanAccent))),
              const SizedBox(height: 20),
              if (!cargando) ...[
                ElevatedButton.icon(onPressed: seleccionar, icon: const Icon(Icons.add_a_photo), label: const Text("1. SUBIR FOTOS")),
                const SizedBox(height: 10),
                ElevatedButton.icon(onPressed: descargarMusica, icon: const Icon(Icons.music_note), label: const Text("2. DESCARGAR MÚSICA"), style: ElevatedButton.styleFrom(backgroundColor: Colors.purple)),
                const SizedBox(height: 10),
                if (fotos.isNotEmpty) ElevatedButton.icon(onPressed: procesarIA, icon: const Icon(Icons.psychology), style: ElevatedButton.styleFrom(backgroundColor: Colors.green), label: const Text("3. GENERAR GUION")),
                const SizedBox(height: 10),
                if (clips.isNotEmpty && rutaMusicaSeleccionada != null) ElevatedButton.icon(onPressed: renderizarVideo, icon: const Icon(Icons.movie), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue), label: const Text("4. RENDERIZAR REEL FINAL")),
                const SizedBox(height: 10),
                if (fotos.isNotEmpty || clips.isNotEmpty) ElevatedButton.icon(onPressed: limpiarTodo, icon: const Icon(Icons.clear), label: const Text("LIMPIAR"), style: ElevatedButton.styleFrom(backgroundColor: Colors.red)),
              ],
              if (cargando) const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
