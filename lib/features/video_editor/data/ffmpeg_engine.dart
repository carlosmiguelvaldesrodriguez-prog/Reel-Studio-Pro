import 'dart:io';
import 'package:process_run/shell.dart';
import '../domain/models/clip.dart';

class FFmpegBeatSyncEngine {
  Future<void> renderEnterpriseReel({
    required List<VideoClip> clips,
    required String audioPath,
    required String outputPath,
    required int bpm,
  }) async {
import 'dart:io';
import 'package:process_run/shell.dart';
import '../domain/models/clip.dart';

class FFmpegBeatSyncEngine {
  final String ffmpegPath = 'ffmpeg.exe'; // Asumiendo que está en el PATH de Windows

  /// Genera un video sincronizado al BPM de la música
  Future<String> renderEnterpriseReel({
    required List<VideoClip> clips,
    required String audioPath,
    required String outputPath,
    required int bpm,
  }) async {
    // Matemáticas de Beat-Sync
    // Ej: 120 BPM = 2 beats por segundo. Un compás (4 beats) = 2.0 segundos.
    double secondsPerBeat = 60.0 / bpm;
    double transitionDuration = secondsPerBeat / 2; // Transición rápida (medio beat)

    List<String> inputs =[];
    String filterGraph = "";
    
    // 1. Preparar Inputs
    for (int i = 0; i < clips.length; i++) {
      inputs.addAll(['-loop', '1', '-t', '${clips[i].durationSeconds + transitionDuration}', '-i', clips[i].imagePath]);
    }
    inputs.addAll(['-i', audioPath]); // Input de audio

    // 2. Construir el Filtergraph complejo (XFADE dinámico)
    double currentOffset = 0.0;
    
    for (int i = 0; i < clips.length - 1; i++) {
      currentOffset += clips[i].durationSeconds;
      
      String in1 = i == 0 ? "[0:v]" : "[v$i]";
      String in2 = "[${i + 1}:v]";
      String out = "[v${i + 1}]";
      
      // Variación dinámica de transiciones basada en el análisis del video adjunto
      String transType = clips[i].transitionType;
      
      filterGraph += "$in1$in2"
          "xfade=transition=$transType:duration=$transitionDuration:offset=$currentOffset"
          "$out;";
    }

    // Limpiar el último punto y coma y formatear el mapeo final
    filterGraph = filterGraph.substring(0, filterGraph.length - 1);
    String finalVideoMap = "[v${clips.length - 1}]";

    // 3. Ensamblar comando FFmpeg
    var shell = Shell();
    List<String> commandArgs =[
      ...inputs,
      '-filter_complex', filterGraph,
      '-map', finalVideoMap,
      '-map', '${clips.length}:a', // Mapear el audio
      '-c:v', 'libx264',
      '-preset', 'fast',
      '-pix_fmt', 'yuv420p',
      '-c:a', 'aac',
      '-shortest', // Cortar cuando termine el video o el audio
      '-y', // Sobrescribir
      outputPath
    ];

    print("Ejecutando FFmpeg Beat-Sync...");
    try {
      await shell.runExecutableArguments(ffmpegPath, commandArgs);
      return outputPath;
    } catch (e) {
      throw Exception("Error en renderizado nativo Windows: $e");
    }
  }  
  }
}


}
