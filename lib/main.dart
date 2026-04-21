import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart'; 
import 'package:google_generative_ai/google_generative_ai.dart'; 
import 'package:image/image.dart' as img; 
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
  String log = "Pega tu API Key, enciende tu VPN y sube las fotos.";
  final TextEditingController _apiKeyController = TextEditingController();

  Future<void> seleccionar() async {
    FilePickerResult? res = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
    if (res != null) setState(() { fotos = res.files; clips = []; log = "Fotos cargadas."; });
  }

  Future<void> procesarIA() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) { setState(() => log = "❌ ERROR: Pega la API Key arriba."); return; }

    setState(() => cargando = true);
    try {
      // CORRECCIÓN REALIZADA: AHORA USAMOS GEMINI 3 FLASH
      final model = GenerativeModel(model: 'gemini-3-flash-preview', apiKey: key);
      
      final images = <DataPart>[];
      for (var f in fotos) {
        final bytes = await File(f.path!).readAsBytes();
        final mini = img.encodeJpg(img.copyResize(img.decodeImage(bytes)!, width: 400), quality: 60);
        images.add(DataPart('image/jpeg', Uint8List.fromList(mini)));
      }
      
      final prompt = TextPart('Director de Arte: Crea un Reel de 30s. 10 escenas de 3s. Transiciones variadas. JSON: {"timeline":[{"image_name":"x","duration_sec":3.0, "transition":"crossfade"}]}');
      final resp = await model.generateContent([Content.multi([...images, prompt])]);
      final data = jsonDecode(resp.text!.replaceAll('```json', '').replaceAll('```', '').trim());
      
      setState(() { 
        clips = (data['timeline'] as List).map((i) => VideoClip.fromJson(i)).toList();
        log = "¡ÉXITO! Guion de ${clips.length} escenas generado con Gemini 3.";
      });
    } catch (e) { setState(() => log = "Error: $e\n(Revisa el VPN de escritorio)"); }
    finally { setState(() => cargando = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IA REEL STUDIO - MOTOR 3.0')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              SizedBox(
                width: 450,
                child: TextField(
                  controller: _apiKeyController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '🔑 Pega aquí tu Nueva API Key', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(height: 20),
              Text(log, textAlign: TextAlign.center, style: const TextStyle(color: Colors.cyanAccent)),
              const SizedBox(height: 20),
              if (!cargando) ...[
                ElevatedButton(onPressed: seleccionar, child: const Text("1. SUBIR FOTOS")),
                const SizedBox(height: 10),
                if (fotos.isNotEmpty) ElevatedButton(onPressed: procesarIA, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text("2. GENERAR GUION (GEMINI 3)")),
              ],
              if (cargando) const CircularProgressIndicator(),
              if (clips.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text("STORYBOARD:", style: TextStyle(fontWeight: FontWeight.bold)),
                for (var c in clips) Text("${c.imageName} | ${c.duration}s | ${c.transition}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
