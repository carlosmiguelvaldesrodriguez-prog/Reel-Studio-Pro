class MusicTrack {
  final String title;
  final String url;
  final int bpm;

  MusicTrack({required this.title, required this.url, required this.bpm});
}

class MusicLibrary {
  // Catálogo estático estructurado
  final Map<String, List<MusicTrack>> catalog = {
    'Cinematic': List.generate(10, (i) => MusicTrack(title: 'Epic Trailer ${i+1}', url: 'https://mockurl.com/cinematic_$i.mp3', bpm: 90)),
    'Urban': List.generate(10, (i) => MusicTrack(title: 'Street Beat ${i+1}', url: 'https://mockurl.com/urban_$i.mp3', bpm: 120)),
    'Pop': List.generate(10, (i) => MusicTrack(title: 'Summer Vibes ${i+1}', url: 'https://mockurl.com/pop_$i.mp3', bpm: 115)),
    'Lo-Fi': List.generate(10, (i) => MusicTrack(title: 'Chill Study ${i+1}', url: 'https://mockurl.com/lofi_$i.mp3', bpm: 80)),
    'Corporate': List.generate(10, (i) => MusicTrack(title: 'Upbeat Tech ${i+1}', url: 'https://mockurl.com/corp_$i.mp3', bpm: 110)),
  };

  // Mock de integración con Text-to-Music API (Gemini Music Integration)
  Future<MusicTrack> generateMusicWithAI(String prompt) async {
    // Simula la llamada a la API generativa
    await Future.delayed(const Duration(seconds: 4));
    
    return MusicTrack(
      title: 'AI Generated: $prompt',
      url: 'https://mockurl.com/ai_generated_temp.mp3',
      bpm: 120, // BPM por defecto para la pista generada
    );
  }
}
