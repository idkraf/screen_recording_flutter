# Android Screen Recorder - Engineering Guide & Architecture Standard

Dokumen ini adalah **Ground Rules & Mandatory Protocol** bagi seluruh proses pengembangan aplikasi *Screen Recorder Android* menggunakan Flutter. Setiap iterasi, refactoring, dan penambahan fitur lanjutan **wajib mematuhi** pedoman yang ada di dalam dokumen ini.

---

## 1. Peran & Prinsip Pengembangan (Roles & Principles)

- **Role:** Senior Mobile Architect & Lead Flutter Developer.
- **Tujuan Proyek:** Membangun aplikasi perekam layar Android personal yang andal, aman, berkinerja tinggi, dan terstruktur rapi.
- **Standar Arsitektur:** Clean Architecture dengan pendekatan *Feature-First* (Modular), memisahkan *Core Services* dengan *Features UI/State*.
- **State Management:** `Provider` (bersih, deterministik, tanpa boilerplate berlebih, dan mudah di-trace).
- **Target OS:** Android Minimum SDK 24 (Android 7.0 Nougat) hingga Android 14+ (API 34).

---

## 2. Multi-Agent Collaboration & Architectural Debate

Sebelum implementasi, dilakukan debat arsitektur antara dua agen spesialis:

```
┌─────────────────────────────────────────────────────────────┐
│                   Multi-Agent Debate                        │
├──────────────────────────────┬──────────────────────────────┤
│  Agent A: Native Channel     │  Agent B: Modular Package    │
│  (Kotlin MediaProjection)    │  (ed_screen_recorder + Svcs) │
├──────────────────────────────┼──────────────────────────────┤
│ • Full control kode native   │ • Implementasi cepat & stabil│
│ • Maintenance tinggi         │ • Native Foreground Service  │
│ • Rentan breakage per Android│ • Standar industri modular   │
│   version update             │ • Mudah di-maintain          │
└──────────────────────────────┴──────────────────────────────┘
```

### Opsi A: Kustom Native Platform Channel (Kotlin `MediaProjection` + `MediaRecorder`) — *(TERPILIH & DIIMPLEMENTASIKAN)*
- **Kelebihan:** 
  1. **100% Modern Flutter Embedding (v2):** Kebal terhadap pemutusan dukungan engine Flutter 3.44+ yang telah menghapus legacy `PluginRegistry.Registrar`.
  2. **Android 14 (API 34) Ready:** Kontrol penuh terhadap inisialisasi `ForegroundService` bertipe `mediaProjection` dengan `ServiceCompat.startForeground`.
  3. **Zero Deprecated Dependencies:** Bebas dari dependensi usang yang tidak terawat di pub.dev.
  4. **Performansi Maksimal:** Encoding langsung pada hardware Android via `VirtualDisplay` & `MediaRecorder`.
- **Keputusan:** **Opsi A terpilih dan diimplementasikan penuh** dengan menghubungkan Kotlin Native (`ScreenCaptureService` & `MainActivity`) ke `ScreenRecorderService` Dart melalui `MethodChannel('com.screenrecording.app/recorder')`. Arsitektur UI tetap bersih dan decoupled.

---

## 3. Safety Net & Checkpoint Strategy

Untuk memastikan aplikasi tidak rapuh (*fragile*), pengembangan dibagi menjadi 3 lapisan independen:

1. **Layer 1: Platform & Manifest Guard**
   - Mendeklarasikan `FOREGROUND_SERVICE_MEDIA_PROJECTION` dan `RECORD_AUDIO`.
   - Mengatur `minSdk = 24` di `build.gradle.kts` dan penanganan *scoped storage*.
2. **Layer 2: Service & State Boundary Isolation**
   - Setiap pemanggilan I/O (rekaman, penyimpanan file, permission) dilindungi blok `try-catch` dengan log yang aman.
   - `RecorderProvider` mengisolasi siklus hidup rekaman melalui *Finite State Machine* (`RecordingState`: `idle` ➔ `starting` ➔ `recording` ➔ `paused` ➔ `stopping`).
3. **Layer 3: UI & Presentation Safeguard**
   - UI bereaksi terhadap state, bukan memicu aksi native secara langsung.
   - Pengecekan `mounted` sebelum navigasi dan manipulasi context.
   - Graceful fallback jika file video rusak atau belum ada izin.

---

## 4. Struktur Direktori Proyek (Clean Architecture)

```text
lib/
├── core/
│   ├── constants/
│   │   ├── app_colors.dart            # Theme tokens (Dark Glassmorphism)
│   │   └── app_theme.dart             # Global ThemeData
│   ├── services/
│   │   ├── permission_service.dart    # Android runtime permissions (Mic, Media, Notif)
│   │   ├── screen_recorder_service.dart # Abstraksi MediaProjection & Hardware Capture
│   │   └── storage_service.dart       # Local filesystem & file cleanup
│   └── utils/
│       └── formatters.dart            # Formatter waktu (00:00:00) & file size (MB)
│
├── features/
│   ├── recorder/                      # Fitur Perekaman Layar
│   │   ├── models/
│   │   │   ├── recording_model.dart   # Model metadata rekaman video
│   │   │   └── recording_state.dart   # State enum (idle, starting, recording, paused, stopping)
│   │   ├── providers/
│   │   │   └── recorder_provider.dart # State manager rekaman & timer ticker
│   │   └── views/
│   │       ├── home_recorder_screen.dart # Screen utama
│   │       └── widgets/
│   │           ├── recording_control_button.dart # 1 Tombol multi-fungsi 4 status
│   │           ├── recording_stats_card.dart     # Toggle mic & info resolusi
│   │           └── recording_timer_badge.dart    # Timer rekaman berkedip
│   │
│   └── recordings_list/               # Fitur Galeri & Playback
│       ├── providers/
│       │   └── recordings_provider.dart # State manager daftar rekaman & sharing
│       └── views/
│           ├── recordings_list_screen.dart # Layar daftar video rekaman
│           ├── video_player_screen.dart    # Pemutar video in-app (scrubber + share)
│           └── widgets/
│               └── recording_item_tile.dart # Card thumbnail & actions item
│
└── main.dart                          # Entry point aplikasi
```

---

## 5. Spesifikasi Alur 1 Tombol Dinamis (4-State Button)

| Status | Tampilan Tombol | Aksi Pengguna | Transisi Berikutnya |
| :--- | :--- | :--- | :--- |
| **1. Mulai (Idle)** | Tombol merah berdenyut (*glow*) + Icon Record | Klik untuk minta izin MediaProjection & mulai | `starting` ➔ `recording` |
| **2. Pause (Recording)** | Tombol Amber/Kuning + Icon Pause | Klik untuk menjeda capture stream | `paused` |
| **3. Resume (Paused)** | Tombol Hijau Emerald + Icon Play | Klik untuk melanjutkan perekaman | `recording` |
| **4. Selesai (Stop)** | Tombol Merah Terintegrasi "Selesai & Simpan" | Klik untuk stop service & simpan file `.mp4` | Simpan ➔ Navigasi ke List Screen |

---

## 6. Protokol Keamanan & Pencegahan Memory Leak

1. **Foreground Service:** Menghindari sistem operasi mematikan proses saat user membuka aplikasi lain untuk direkam.
2. **Timer Disposal:** Menghentikan `Timer.periodic` di `RecorderProvider` saat `dispose()` atau rekaman berhenti.
3. **Controller Disposal:** Memastikan `VideoPlayerController` di-`dispose` segera saat user menutup layar pemutar video untuk membebaskan hardware video decoder.
4. **Scoped Storage Compliance:** Menggunakan path aman di direktori aplikasi (`getApplicationDocumentsDirectory`) yang tidak memerlukan izin berbahaya pada Android 11+.

---

## 7. Cara Menjalankan Aplikasi

1. Ambil dependensi:
   ```bash
   flutter pub get
   ```
2. Verifikasi static analysis:
   ```bash
   flutter analyze
   ```
3. Pasang dan jalankan di perangkat fisik Android:
   ```bash
   flutter run
   ```
4. Izinkan dialog sistem Android: *"Start recording or casting with Screen Recorder Pro?"* ➔ Pilih **"Start now"**.
