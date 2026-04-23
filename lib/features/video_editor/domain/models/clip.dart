class VideoClip {
  final String id;
  final String imagePath;
  double durationSeconds;
  String transitionType; // ej. 'fade', 'wipeleft', 'circlecrop'

  VideoClip({
    required this.id,
    required this.imagePath,
    this.durationSeconds = 2.0,
    this.transitionType = 'fade',
  });
}
