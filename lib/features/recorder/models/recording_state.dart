/// Status siklus perekaman layar
enum RecordingState {
  /// Aplikasi siap merekam (Kondisi 1: Tombol "Mulai")
  idle,

  /// Sedang menginisialisasi atau hitung mundur
  starting,

  /// Sedang merekam layar aktif (Kondisi 2: Tombol "Pause")
  recording,

  /// Rekaman dijeda sementara (Kondisi 3: Tombol "Lanjutkan")
  paused,

  /// Sedang menghentikan & menyimpan file (Kondisi 4: "Selesai")
  stopping,
}

extension RecordingStateExtension on RecordingState {
  bool get isIdle => this == RecordingState.idle;
  bool get isStarting => this == RecordingState.starting;
  bool get isRecording => this == RecordingState.recording;
  bool get isPaused => this == RecordingState.paused;
  bool get isStopping => this == RecordingState.stopping;
  bool get isActive => isRecording || isPaused;
}
