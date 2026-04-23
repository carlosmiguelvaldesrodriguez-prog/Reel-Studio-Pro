import 'package:flutter/material.dart';
import 'features/market_intelligence/data/market_agent.dart';
import 'features/music_jukebox/data/music_library.dart';
import 'features/video_editor/domain/models/clip.dart';
import 'features/video_editor/presentation/timeline_ui.dart';
import 'features/video_editor/data/ffmpeg_engine.dart';

void main() {
  runApp(const IAReelStudioPro());
}

class IAReelStudioPro extends StatelessWidget {
  const IAReelStudioPro({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IA Reel Studio Pro - Enterprise',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        primaryColor: Colors.amber,
        colorScheme: const ColorScheme.dark(primary: Colors.amber, secondary: Colors.amberAccent),
        fontFamily: 'Segoe UI', // Tipografía limpia para Windows
      ),
      home: const MainWorkspace(),
    );
  }
}

class MainWorkspace extends StatefulWidget {
  const MainWorkspace({Key? key}) : super(key: key);

  @override
  _MainWorkspaceState createState() => _MainWorkspaceState();
}

class _MainWorkspaceState extends State<MainWorkspace> {
  final MarketIntelligenceAgent _marketAgent = MarketIntelligenceAgent();
  final MusicLibrary _musicLibrary = MusicLibrary();
  final FFmpegBeatSyncEngine _ffmpegEngine = FFmpegBeatSyncEngine();

  List<VideoClip> _currentClips =[];
  MusicTrack? _selectedTrack;
  bool _isAgentLoading = false;
  bool _isRendering = false;
  String _chatHistory = "Agente: ¡Hola! Listo para analizar el mercado.\n";

  @override
  void initState() {
    super.initState();
    // Cargar clips por defecto
    _currentClips =[
      VideoClip(id: '1', imagePath: 'https://via.placeholder.com/150/000000/FFFFFF/?text=Foto+1'),
      VideoClip(id: '2', imagePath: 'https://via.placeholder.com/150/111111/FFFFFF/?text=Foto+2'),
      VideoClip(id: '3', imagePath: 'https://via.placeholder.com/150/222222/FFFFFF/?text=Foto+3'),
    ];
  }

  Future<void> _askAgentForStrategy() async {
    setState(() => _isAgentLoading = true);
    try {
      final strategy = await _marketAgent.analyzeMarketAndRecommend();
      setState(() {
        _chatHistory += "\nAgente: Sugiero el nicho '${strategy['niche']}'. ${strategy['market_insight']}\n";
        _chatHistory += "BPM Recomendado: ${strategy['recommended_bpm']}. Estilo: ${strategy['recommended_style']}.\n";
      });

      // Mostrar diálogo para aplicar sugerencia
      _showStrategyDialog(strategy);
    } finally {
      setState(() => _isAgentLoading = false);
    }
  }

  void _showStrategyDialog(Map<String, dynamic> strategy) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Estrategia Generada', style: TextStyle(color: Colors.amber)),
        content: Text('¿Aplicar configuración para ${strategy['niche']}?'),
        actions:[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ignorar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            onPressed: () {
              _applyStrategy(strategy);
              Navigator.pop(context);
            },
            child: const Text('Aplicar Sugerencia'),
          ),
        ],
      ),
    );
  }

  void _applyStrategy(Map<String, dynamic> strategy) {
    setState(() {
      // Aplicar pista musical sugerida (tomamos la primera del estilo recomendado)
      _selectedTrack = _musicLibrary.catalog[strategy['recommended_style']]?.first;
      
      // Actualizar clips según la configuración sugerida
      List<dynamic> config = strategy['suggested_clips_config'];
      for (int i = 0; i < _currentClips.length && i < config.length; i++) {
        _currentClips[i].durationSeconds = config[i]['duration'];
        _currentClips[i].transitionType = config[i]['transition'];
      }
    });
  }

  Future<void> _renderVideo() async {
    if (_selectedTrack == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona una pista de audio primero')));
      return;
    }
    setState(() => _isRendering = true);
    try {
      // Simulación de llamada al motor FFmpeg
      await Future.delayed(const Duration(seconds: 3)); // Simula el tiempo de render
      /* Descomentar en producción:
      await _ffmpegEngine.renderEnterpriseReel(
        clips: _currentClips,
        audioPath: _selectedTrack!.url,
        outputPath: 'C:\\temp\\output_reel.mp4',
        bpm: _selectedTrack!.bpm,
      );
      */
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Renderizado completado con éxito!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isRendering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: const Text('IA Reel Studio Pro', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions:[
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(_selectedTrack != null ? '🎵 ${_selectedTrack!.title} (${_selectedTrack!.bpm} BPM)' : 'Sin música', 
                style: const TextStyle(color: Colors.amber)),
            ),
          )
        ],
      ),
      body: Row(
        children:[
          // Panel Lateral: Agente de Mercado
          Container(
            width: 300,
            color: const Color(0xFF1A1A1A),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:[
                const Text('Market Intelligence', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(_chatHistory, style: const TextStyle(color: Colors.white70, height: 1.5)),
                  ),
                ),
                if (_isAgentLoading) const Center(child: CircularProgressIndicator(color: Colors.amber)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.auto_awesome, color: Colors.black),
                    label: const Text('Analizar Mercado', style: TextStyle(color: Colors.black)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, padding: const EdgeInsets.symmetric(vertical: 16)),
                    onPressed: _isAgentLoading ? null : _askAgentForStrategy,
                  ),
                )
              ],
            ),
          ),
          // Área Principal: Editor
          Expanded(
            child: Column(
              children:[
                // Vista Previa (Placeholder)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF333333)),
                    ),
                    child: const Center(child: Icon(Icons.play_circle_outline, size: 64, color: Colors.white24)),
                  ),
                ),
                // Timeline Interactivo
                InteractiveTimeline(
                  clips: _currentClips,
                  onTimelineChanged: (newClips) {
                    setState(() => _currentClips = newClips);
                  },
                ),
                // Barra de Controles Inferior
                Container(
                  padding: const EdgeInsets.all(16.0),
                  color: const Color(0xFF121212),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children:[
                      ElevatedButton.icon(
                        icon: _isRendering 
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.movie_creation),
                        label: Text(_isRendering ? 'Renderizando...' : 'Exportar Reel'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        ),
                        onPressed: _isRendering ? null : _renderVideo,
                      )
                    ],
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
