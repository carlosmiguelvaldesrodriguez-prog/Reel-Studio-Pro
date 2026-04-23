import 'dart:convert';
import 'dart:async';

class MarketIntelligenceAgent {
  // Simulación de la API de Gemini 3 Flash
  Future<Map<String, dynamic>> analyzeMarketAndRecommend() async {
    // Simulamos el delay de red y procesamiento del LLM (RAG + Web Scraping)
    await Future.delayed(const Duration(seconds: 3));

    // Prompt de sistema interno (simulado):
    // "Actúa como un analista de marketing. Analiza las tendencias de los últimos 7 días 
    // en Instagram y Facebook para estudios fotográficos en Santa Clara, Cuba. 
    // Devuelve un JSON con el nicho más rentable, BPM recomendado, y configuración de clips."

    // Respuesta simulada del LLM basada en el análisis de mercado
    String geminiJsonResponse = '''
    {
      "niche": "Quinceañeras Urbanas",
      "market_insight": "Alta saturación en bodas tradicionales. Las sesiones de quinceañeras con estilo urbano/neón en el centro de Santa Clara tienen un 400% más de engagement esta semana.",
      "recommended_bpm": 120,
      "recommended_style": "Urban",
      "suggested_clips_config":[
        {"duration": 2.0, "transition": "fade"},
        {"duration": 1.0, "transition": "zoom"},
        {"duration": 0.5, "transition": "luma_wipe"},
        {"duration": 0.5, "transition": "pixelize"},
        {"duration": 2.0, "transition": "fade"}
      ]
    }
    ''';

    return jsonDecode(geminiJsonResponse);
  }

  Future<String> chatWithAgent(String userMessage) async {
    await Future.delayed(const Duration(seconds: 1));
    if (userMessage.toLowerCase().contains("hola")) {
      return "¡Hola! Soy tu Agente de Mercado. He analizado las redes en Santa Clara. ¿Quieres que genere una estrategia para tu próximo Reel?";
    }
    return "Basado en las métricas actuales, te sugiero aplicar la estrategia de 'Quinceañeras Urbanas'. Usa el botón de sugerencia para aplicarla al timeline.";
  }
}
