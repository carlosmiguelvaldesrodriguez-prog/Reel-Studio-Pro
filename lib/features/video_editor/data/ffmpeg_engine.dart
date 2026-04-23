import 'dart:io';
import 'package:process_run/shell.dart';
import '../domain/models/clip.dart';

class FFmpegBeatSyncEngine {
  // Asumimos que ffmpeg.exe está en una carpeta 'bin' al lado del .exe principal
  final String ffmpegPath;

  FFmpegBeatSyncEngine() : ffmpegPath = "${Directory.current.path}\\bin\\ffmpeg.exe";

  Future<String> renderEnterpriseReel({
    required List<VideoClip> clips,
    required String audioPath,
    required String outputPath,
    required int bpm,
  }) async {
    if (!File(ffmpegPath).existsSync()) {
      throw Exception("FATAL: ffmpeg.exe no encontrado en la carpeta 'bin'.");
    }

    double transitionDuration = 0.5; // Medio segundo de transición
    List<String> inputs = [];
    String filterGraph = "";
    
    // 1. Preparar Inputs de imágenes y escalarlas a 9:16
    for (int i = 0; i < clips.length; i++) {
      double duracionConExtra = clips[i].durationSeconds + transitionDuration;
      String rutaFotoLimpia = clips[i].imagePath.replaceAll(r'\', '/');
      inputs.addAll(['-loop', '1', '-t', '$duracionConExtra', '-i', rutaFotoLimpia]);
      filterGraph += "[$i:v]scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:-1:-1:color=black,format=yuv420p,setsar=1[v$i];";
    }
    
    // 2. Preparar Input de audio
    inputs.addAll(['-i', audioPath.replaceAll(r'\', '/')]);
    int audioIndex = clips.length;

    // 3. Construir la cadena de transiciones dinámicas (XFADE)
    String lastOutput = "[v0]";
    double currentOffset = clips[0].durationSeconds - transitionDuration;
    if (currentOffset < 0) currentOffset = 0;

    for (int i = 0; i < clips.length - 1; i++) {
      String nextInput = "[v${i + 1}]";
      String transType = clips[i+1].transitionType.toLowerCase(); // La transición del clip que ENTRA
      
      // Diccionario de seguridad para evitar errores de FFmpeg
      const validTransitions = {'wipeleft', 'wiperight', 'slideup', 'slidedown', 'pixelize', 'fade'};
      if (!validTransitions.contains(transType)) transType = 'fade';
      
      filterGraph += "$lastOutput$nextInput"
          "xfade=transition=$transType:duration=$transitionDuration:offset=$currentOffset"
          "[f${i + 1}];";
      lastOutput = "[f${i + 1}]";
      currentOffset += clips[i + 1].durationSeconds - transitionDuration;
    }

    // 4. Ensamblar comando final para Windows
    var shell = Shell(verbose: false);
    List<String> commandArgs = [
      ...inputs,
      '-filter_complex', filterGraph,
      '-map', lastOutput,
      '-map', '$audioIndex:a',
      '-c:v', 'libx264',
      '-preset', 'fast', // Más rápido en Celeron a costa de un poco de calidad
      '-pix_fmt', 'yuv420p',
      '-t', '30', // Corte estricto a 30 segundos
      '-y',
      outputPath.replaceAll(r'\', '/')
    ];

    try {
      var result = await shell.runExecutableArguments(ffmpegPath, commandArgs);
      if (result.exitCode == 0) {
        return outputPath;
      } else {
        throw Exception("FFmpeg falló. Código de salida: ${result.exitCode}\nError: ${result.stderr}");
      }
    } catch (e) {
      throw Exception("Error de Proceso Nativo Windows: $e");
    }
  }
}
