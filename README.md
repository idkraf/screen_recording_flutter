# REKAM (com.aplikasi.rekam) - Android Screen Recorder Architecture & Engineering Standard

Dokumen ini adalah **Ground Rules & Mandatory Protocol** bagi seluruh proses pengembangan aplikasi *REKAM* menggunakan Flutter. Setiap iterasi, refactoring, dan penambahan fitur lanjutan **wajib mematuhi** pedoman yang ada di dalam dokumen ini.

---

## 1. Peran & Prinsip Pengembangan (Roles & Principles)

### 1.1 Identitas & Arsitektur Inti
- **Role:** Senior Mobile Architect, Security Expert, & Lead AI Engineering Supervisor.
- **Tujuan Proyek:** Membangun aplikasi perekam layar Android personal yang andal, aman, berkinerja tinggi, dan terstruktur rapi dengan paket aplikasi `com.aplikasi.rekam`.
- **Standar Arsitektur:** Clean Architecture dengan pendekatan *Feature-First* (Modular), memisahkan *Core Services* dengan *Features UI/State*.
- **State Management:** `Provider` (bersih, deterministik, tanpa boilerplate berlebih, dan mudah di-trace).
- **Target OS:** Android Minimum SDK 24 (Android 7.0 Nougat) hingga Android 14 & 15 (API 34/35).
- **Package Name / Application ID:** `com.aplikasi.rekam`

### 1.2 Lima Pilar Protokol Wajib (Mandatory Engineering Protocols)

Seluruh proses analisis, perancangan, penulisan kode, dan refactoring wajib menjalankan **5 Pilar Protokol Pengembangan Tingkat Lanjut** berikut secara berjenjang:

1. **Adversarial (Critical Code Review & Vulnerability Hunt):**
   - Sebelum kode dinyatakan selesai atau diintegrasikan, lakukan audit kritis mandiri (*adversarial simulation*).
   - Menguliti, menguji batas toleransi ekstrem, dan secara proaktif mencari celah keamanan: potensi kebocoran data, risiko *memory leak* pada stream perekaman layar (*MediaProjection*), kegagalan siklus hidup (*lifecycle state*), serta potensi *crash* pada perizinan Android 14 & 15.

2. **Multi-Agent Debate (Multi-Perspective Architecture Discussion):**
   - Untuk setiap penyelesaian masalah non-trivial, pemilihan modul *native bridge*, strategi penyimpanan, atau sinkronisasi background, simulasikan perdebatan dari sudut pandang agen spesialis yang berbeda:
     - *Performance Optimization Expert* (latensi, alokasi memori, frame-drop).
     - *Security & Privacy Advocate* (isolasi Keystore, izin minimum, zero-leak secrets).
     - *UX & Usability Specialist* (responsivitas UI, penanganan error ramah pengguna).
   - Analisis trade-off dan saling uji argumen hingga dicapai kesimpulan arsitektur yang paling kokoh dan seimbang sebelum kode ditulis.

3. **Safety Net (Checkpoint & Rollback Strategy):**
   - Setiap iterasi perubahan signifikan (seperti Media3 Transformer, Service Native, atau autentikasi) dipecah menjadi unit-unit modular yang terisolasi.
   - Wajib menyertakan penanganan error defensif (*graceful fallback* & *try-catch* komprehensif) dan pengujian otomatis, sehingga apabila terjadi regresi atau kendala tak terduga, perubahan dapat di-rollback seketika tanpa merusak kestabilan modul yang sudah berjalan.

4. **Skill & Dependency Security Scan:**
   - Sebelum menyarankan atau memasang *plugin/dependency* pihak ketiga ke dalam `pubspec.yaml`, lakukan audit ketat terhadap:
     - Kredibilitas paket dan reputasi *publisher* di pub.dev.
     - Potensi kerentanan keamanan dan kesesuaian *null-safety*.
     - Dampak terhadap ukuran biner (*APK bloat*) dan *runtime performance overhead*.

5. **Scheduled SOP (Routine Workflow Enforcement):**
   - Menjadwalkan dan menegakkan rutinitas pengembangan terstruktur dalam 4 fase sekuensial di setiap sesi:
     - **Fase 1 (Analisis & Perdebatan):** Eksplorasi solusi dan penajaman arsitektur melalui *Multi-Agent Debate*.
     - **Fase 2 (Implementasi Modular):** Eksekusi bertahap berlandaskan strategi *Safety Net*.
     - **Fase 3 (Audit Dependensi & Secrets):** Verifikasi kepatuhan *Skill & Dependency Security Scan* serta *Secrets Hygiene*.
     - **Fase 4 (Adversarial Testing):** Pengujian ketahanan kode, audit statis (`flutter analyze`), dan unit tests (`flutter test`).

---

## 2. Spesifikasi Teknis & Lingkungan Proyek

### 2.1 Kompatibilitas Android 14 & 15 (MediaProjection & Foreground Service)
- **Aturan Ketat Android 14+:** Izin `MediaProjection` (tangkap layar) **wajib diminta terlebih dahulu via Activity (`startActivityForResult`)** sebelum *Foreground Service* dengan tipe `mediaProjection` (`FOREGROUND_SERVICE_MEDIA_PROJECTION`) dijalankan. Menjalankan service sebelum user menyetujui prompt dialog sistem akan menyebabkan `SecurityException` seketika.
- `AndroidManifest.xml` wajib mendeklarasikan:
  - `android.permission.RECORD_AUDIO`
  - `android.permission.FOREGROUND_SERVICE`
  - `android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION`
  - `android.permission.POST_NOTIFICATIONS`

### 2.2 Desain Splash Screen Non-Putih (`#205080`)
> [!IMPORTANT]
> **Kebijakan Splash Screen:**
> Latar belakang splash screen **TIDAK BOLEH PUTIH POLOS (`#FFFFFF`)**.
> Warna latar splash screen wajib diselaraskan dengan warna latar belakang aset ikon aplikasi `ic_launcher.png`, yaitu **`#205080` (Deep Prussian/Ocean Blue)**.
> - **Android 12+ SplashScreen API:** Dikonfigurasi dengan `android:windowSplashScreenBackground = #205080` dan `android:windowSplashScreenAnimatedIcon = @mipmap/ic_launcher`.
> - **Legacy Android:** Dikonfigurasi di `drawable/launch_background.xml` dengan layer solid `#205080` dan ikon `@mipmap/ic_launcher` di tengah.

---

## 3. Matriks Aturan Akses (Access Control Rules)

Aplikasi menerapkan pembagian hak akses fitur yang ketat namun ramah pengguna:

| Fitur | Syarat Akses | Keterangan |
| :--- | :--- | :--- |
| **Perekaman Layar Dasar** | Bebas (Offline / Tanpa Login) | Perekaman layar, jeda (pause), resume, dan simpan file MP4 ke penyimpanan lokal dapat digunakan kapan saja tanpa perlu login. |
| **Pemutar Video & Potong Frame** | Bebas (Offline / Tanpa Login) | Pemutaran video rekaman lokal dan fitur potong/edit frame (Media3 Transformer) tidak membutuhkan login. |
| **Google Drive Backup** | Login Google via Firebase | Mengunggah video hasil rekaman ke Google Drive pribadi pengguna (*No API Owner / No Default Service Account*). |
| **AI Assistant (Chapters & Summary)** | **Ketat (Wajib 2 Syarat)**:<br>1. Login Google via Firebase<br>2. Valid BYOK Gemini API Key | Tombol AI terkunci secara dinamis jika salah satu syarat belum terpenuhi. Pengguna dipandu melalui dialog interaktif. |

---

## 4. Firebase Authentication & Personal Google Drive Protocol

### 4.1 Firebase Google Sign-In
- Menggunakan `firebase_core` dan `firebase_auth` bersama `google_sign_in`.
- Menyediakan status autentikasi reaktif yang dapat diamati melalui `AuthProvider`.
- **Graceful Fallback:** Aplikasi dirancang agar tetap dapat di-build dan berjalan normal meskipun file `google-services.json` belum diletakkan di environment lokal saat tahap pengembangan awal.

### 4.2 Google Drive Pribadi (Personal Drive Storage)
- User menggunakan token otentikasi akun Google pribadi mereka untuk mengunggah file ke Google Drive (`https://www.googleapis.com/auth/drive.file`).
- **Keamanan:** Tidak menggunakan service account terpusat atau API Owner milik developer, sehingga kapasitas penyimpanan dan kepemilikan data sepenuhnya berada di tangan pengguna.

### 4.3 Firebase Crashlytics (Pelaporan Crash & Error Telemetry)
- Terintegrasi melalui modul terpusat [`CrashlyticsService`](file:///d:/Project/Fastwork/screenrecording/lib/core/services/crashlytics_service.dart).
- **Dual Global Handlers:**
  1. `FlutterError.onError`: Menangkap unhandled exception fatal dari framework widget Flutter (`recordFlutterFatalError`).
  2. `PlatformDispatcher.instance.onError`: Menangkap asynchronous unhandled errors di luar framework (`recordError(..., fatal: true)`).
- **Graceful Fallback:** Aman dijalankan saat offline atau ketika Firebase belum terhubung (tidak menyebabkan crash saat initialization).
- **Debug vs Release Policy:** Pengumpulan crash diatur otomatis aktif pada mode release (`!kDebugMode`).
- **User Attribution:** Terhubung dengan `AuthProvider` untuk melampirkan UID akun Google saat terjadi exception.

### 4.4 Google Analytics (Pelacakan Event & Performa Pengguna)
- Terintegrasi melalui modul terpusat [`AnalyticsService`](file:///d:/Project/Fastwork/screenrecording/lib/core/services/analytics_service.dart).
- **Navigasi Layar Otomatis:** Menggunakan `FirebaseAnalyticsObserver` yang didaftarkan pada `MaterialApp.navigatorObservers`.
- **Daftar Event Standar Aplikasi:**
  - `recording_started`: Dilengkapi parameter `with_audio` (1/0) dan resolusi layar (misal: `1080x1920`).
  - `recording_saved`: Dilengkapi parameter `duration_seconds` dan `file_size_bytes`.
  - `ai_analysis_requested`: Dicatat saat user meminta analisis timeline video (`analysis_type: timeline_summary`).
  - `ai_command_executed`: Dicatat saat user mengirim prompt perintah AI (`command_char_length`).
  - `login` & `user_logout`: Melacak sesi akun Google dan mengaitkan User ID pengguna pada dashboard analitik.

---

## 5. AI Video Editor Assistant (Account-Bound Intelligence & BYOK Protocol)

### 5.1 Filosofi Intelligence Layer (Bukan Video Editor Visual)
> [!NOTE]
> AI Assistant bertindak **murni sebagai penganalisis cerdas dan asisten penyuntingan**, bukan mesin rendering atau pengedit video visual.
> - **Tugas AI:** Menganalisis visual UI, mendeteksi transisi layar, menyusun *Smart Video Chapters*, merangkum langkah-langkah aktivitas layar (*Smart Timeline Summarizer*), serta menjawab pertanyaan timestamp secara interaktif (*Command-Based Assistant*).
> - **Tugas Video Editing:** Pemotongan frame fisik dilakukan oleh modul native hardware Android (`Media3 Transformer`), bukan oleh AI.

### 5.2 Arsitektur Account-Bound AI Service (`VideoAiService`) & Isolasi Multi-User
1. **Validasi Sesi Aktif Mutlak:** Modul `VideoAiService` memvalidasi status sesi `FirebaseAuth.instance.currentUser`. Jika tidak ada pengguna yang sedang login via Google Firebase, pemrosesan AI ditolak seketika (`UnauthenticatedException`).
2. **Isolasi Multi-User Android Keystore:** Kunci API disimpan secara terenkripsi menggunakan `flutter_secure_storage` dengan skema berbasis UID akun: `gemini_api_key_<user_uid>`. Jika perangkat berganti akun Google, kunci API milik akun sebelumnya tetap terisolasi dan aman.
3. **Zero Hardcoded Secrets (BYOK):** Tidak ada API key yang ditanam di dalam bundle aplikasi. Pengguna memasukkan Gemini API Key pribadi (dapat diperoleh gratis di [Google AI Studio](https://aistudio.google.com/)).

### 5.3 Fitur Inti AI Video Editor Assistant
- **1. Smart Timeline Summarizer:** Menganalisis video rekaman layar multimodal menggunakan Gemini 1.5 Flash untuk menghasilkan ringkasan kronologis berpoin (•) beserta babak otomatis (*Smart Chapters*) yang dapat langsung diklik untuk melompat ke detik yang diinginkan.
- **2. Command-Based Assistant:** Menerima *prompt* teks bebas dari pengguna terautentikasi (misal: *"Carikan timestamp saat saya membuka menu pengaturan"*, *"Kapan notifikasi error muncul?"*). Gemini menjawab secara kontekstual dan menyediakan tombol navigasi seek detik otomatis.

### 5.4 Proteksi Akses Mutlak (Strict Guard Enforcer)
Tombol dan fitur AI pada Halaman Video Player dilindungi oleh guard ketat:
1. **User Google Terautentikasi:** Wajib login via Firebase Google Sign-In.
2. **Valid BYOK Gemini Key:** Kunci API telah tersimpan dan terverifikasi untuk akun tersebut.
- *Jika salah satu syarat belum terpenuhi, tombol AI berstatus terkunci (dengan ikon lock) dan mengarahkan pengguna secara elegan ke Halaman Profil.*

---

## 6. Spesifikasi Alur 1 Tombol Dinamis (4-State Button)

| Status | Tampilan Tombol | Aksi Pengguna | Transisi Berikutnya |
| :--- | :--- | :--- | :--- |
| **1. Mulai (Idle)** | Tombol merah berdenyut (*glow*) + Icon Record | Memicu izin MediaProjection & mulai service | `starting` ➔ `recording` |
| **2. Pause (Recording)** | Tombol Amber/Kuning + Icon Pause | Menjeda capture stream native | `paused` |
| **3. Resume (Paused)** | Tombol Hijau Emerald + Icon Play | Melanjutkan perekaman layar | `recording` |
| **4. Selesai (Stop)** | Tombol Merah Terintegrasi "Selesai & Simpan" | Stop service & simpan file `.mp4` ke lokal | Simpan ➔ Navigasi ke List Screen |

---

## 7. Struktur Direktori Proyek (Clean Architecture)

```text
lib/
├── core/
│   ├── constants/
│   │   ├── app_colors.dart            # Theme tokens (Dark Slate & Ocean Blue)
│   │   └── app_theme.dart             # Global ThemeData
│   ├── providers/
│   │   └── auth_provider.dart         # State manager Firebase Google Sign-In
│   ├── services/
│   │   ├── ai_guard_service.dart      # Validasi hak akses AI (Auth + Key per-UID)
│   │   ├── ai_service.dart            # Utilitas testing koneksi Gemini API
│   │   ├── api_key_storage_service.dart # Android Keystore via flutter_secure_storage (Multi-user)
│   │   ├── auth_service.dart          # Firebase Auth & Google Sign-In
│   │   ├── google_drive_service.dart  # Upload video ke Google Drive pribadi
│   │   ├── permission_service.dart    # Android runtime permissions
│   │   ├── screen_recorder_service.dart # Abstraksi MediaProjection & Hardware Capture
│   │   ├── storage_service.dart       # Local filesystem & file cleanup
│   │   ├── video_ai_service.dart      # Account-Bound AI Video Assistant (Timeline & Command)
│   │   └── video_editor_service.dart  # Native Media3 video cutting
│   └── utils/
│       └── formatters.dart            # Formatter waktu & file size
│
├── features/
│   ├── profile/                       # Halaman Profil Terproteksi & AI Settings
│   │   └── views/
│   │       └── profile_screen.dart    # Halaman profil Google user & setup Gemini API Key
│   │
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
│   │           ├── recording_timer_badge.dart    # Timer rekaman berkedip
│   │           └── user_profile_dialog.dart      # Dialog profil & Google Login
│   │
│   └── recordings_list/               # Fitur Galeri & Playback
│       ├── models/
│       │   └── ai_analysis_model.dart # Model Smart Chapters, Summary & AiCommandResponse
│       ├── providers/
│       │   └── recordings_provider.dart # State manager daftar rekaman & sharing
│       └── views/
│           ├── recordings_list_screen.dart # Layar daftar video rekaman
│           ├── video_edit_screen.dart      # Layar editor potong frame presisi
│           ├── video_player_screen.dart    # Pemutar video in-app (AI Chapters + Drive)
│           └── widgets/
│               ├── ai_analysis_bottom_sheet.dart # Panel 2-Tab: Smart Timeline & Command Assistant
│               ├── gemini_api_key_dialog.dart    # Dialog BYOK Gemini API Key
│               └── recording_item_tile.dart      # Card thumbnail & actions item
│
├── firebase_options.dart              # Konfigurasi multi-platform FlutterFire
└── main.dart                          # Entry point aplikasi (Firebase safe-init)
```

---

## 8. Panduan Setup Lingkungan Lokal & Secrets Hygiene (Step-by-Step Local Setup Guide)

Demi menjaga keamanan data pengguna, arsitektur *Zero Hardcoded Secrets*, dan kepatuhan terhadap standar repositori terbuka, file konfigurasi Firebase, kunci penandatanganan aplikasi (*keystore*), serta API Key **dilarang keras ter-commit ke dalam Git**.

---

### 8.1 Aturan Pengecualian Git & Kebersihan Secrets (Secrets Hygiene)

Seluruh developer yang mengkloning repositori ini wajib memastikan file-file berikut berada dalam status **diabaikan (ignored)** oleh Git:

| Kategori | File / Pola yang Diabaikan | Alasan Keamanan |
| :--- | :--- | :--- |
| **Firebase Configuration** | `lib/firebase_options.dart`<br>`android/app/google-services.json`<br>`ios/Runner/GoogleService-Info.plist`<br>`firebase.json`, `.firebaserc` | Menampung API Key publik Firebase, App ID, dan kredensial proyek cloud. |
| **Android Keystore** | `*.jks`, `*.keystore`<br>`rekam.jks`, `**/rekam.jks`<br>`key.properties`, `**/key.properties`<br>`local.properties` | Menampung private key dan password sertifikat penandatanganan rilis APK/AAB. |
| **Local Storage / BYOK** | `flutter_secure_storage` data lokal | Gemini API Key pengguna hanya tersimpan di hardware Keystore perangkat, bukan di Git/database. |
| **Build Artifacts** | `build/`, `**/build/`<br>`.dart_tool/`, `.pub/`, `.pub-cache/` | Artefak kompilasi dan cache lokal yang tidak boleh mengotori git history. |

> [!TIP]
> Telah disediakan berkas template referensi yang aman di dalam repositori:
> - `lib/firebase_options.dart.example` ➔ Template struktur `DefaultFirebaseOptions`.
> - `android/key.properties.example` ➔ Template konfigurasi penandatanganan release.

---

### 8.2 Panduan Setup Firebase & FlutterFire CLI

Ikuti langkah-langkah berikut untuk mengonfigurasi Firebase pada komputer lokal Anda:

#### 1. Instalasi Prasyarat
- Pasang [Firebase CLI](https://firebase.google.com/docs/cli) secara global:
  ```bash
  npm install -g firebase-tools
  ```
- Login ke akun Google Firebase Anda:
  ```bash
  firebase login
  ```
- Pasang FlutterFire CLI secara global menggunakan Dart:
  ```bash
  dart pub global activate flutterfire_cli
  ```
- Pastikan direktori bin Pub Cache telah terdaftar pada variabel lingkungan `PATH` sistem Anda:
  - **Windows:** `%LOCALAPPDATA%\Pub\Cache\bin`
  - **macOS / Linux:** `~/.pub-cache/bin`

#### 2. Menghubungkan Proyek dengan Firebase Console
Jalankan perintah konfigurasi otomatis di direktori root proyek:
```bash
flutterfire configure --project=omni-fd919
```
- Pilih platform: **`android`** (atau platform lain sesuai kebutuhan).
- Konfirmasi Package Name / Application ID:
  ```text
  com.aplikasi.rekam
  ```
- Perintah ini secara otomatis akan men-generate berkas lokal:
  - `lib/firebase_options.dart` (terproteksi di `.gitignore`)
  - `android/app/google-services.json` (terproteksi di `.gitignore`)

#### 3. Peletakan Manual `google-services.json` (Alternatif jika tidak memakai CLI)
Jika Anda tidak menggunakan FlutterFire CLI:
1. Buka [Firebase Console](https://console.firebase.google.com/) > Masuk ke Project Settings (⚙️).
2. Pada bagian **Your apps**, pilih aplikasi Android `com.aplikasi.rekam`.
3. Unduh berkas **`google-services.json`**.
4. Letakkan berkas tersebut secara manual ke dalam folder:
   ```text
   android/app/google-services.json
   ```
5. Salin template `lib/firebase_options.dart.example` menjadi `lib/firebase_options.dart` lalu sesuaikan dengan nilai API Key dan Project ID proyek Anda.

---

### 8.3 Panduan Keystore Android (Release & Debug Signing)

Untuk melakukan *build* rilis bertanda tangan (*Signed Release APK / AAB*):

#### 1. Pembuatan Keystore Rilis (`rekam.jks`)
Buat keystore lokal baru menggunakan utilitas `keytool` (bawaan JDK):
```bash
keytool -genkey -v -keystore android/app/rekam.jks -alias rekam_release_key -keyalg RSA -keysize 2048 -validity 10000
```
*(Simpan password keystore dengan aman di password manager lokal Anda).*

#### 2. Konfigurasi `key.properties`
Salin template `android/key.properties.example` menjadi `android/key.properties`:
```properties
storePassword=PASSWORD_KEYSTORE_ANDA
keyPassword=PASSWORD_KEY_ANDA
keyAlias=rekam_release_key
storeFile=rekam.jks
```

#### 3. Pendaftaran SHA-1 & SHA-256 Fingerprint di Firebase Console
Untuk mengaktifkan Google Sign-In dan integrasi Google Drive, daftarkan fingerprint sertifikat:
- Cek fingerprint keystore rilis:
  ```bash
  keytool -list -v -keystore android/app/rekam.jks -alias rekam_release_key
  ```
- Cek fingerprint keystore debug (di `~/.android/debug.keystore`):
  ```bash
  keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
  ```
- Buka **Firebase Console** > **Project Settings** > pilih app **`com.aplikasi.rekam`** > klik **Add fingerprint**, masukkan nilai **SHA-1** dan **SHA-256** dari kedua keystore tersebut.
- Buka **Authentication** > **Sign-in method** > aktifkan penyedia **Google** dan simpan.

---

### 8.4 Panduan BYOK (Bring Your Own Key) Gemini AI Assistant

Fitur AI Assistant (Smart Timeline & Command Assistant) dirancang menggunakan prinsip **Zero Centralized Database & BYOK**:

1. **Input Mandiri Pengguna:**
   - Gemini API Key tidak pernah dimasukkan oleh developer ke dalam source code ataupun server backend.
   - Pengguna memasukkan API Key pribadi mereka melalui **Halaman Profil** (`ProfileScreen`) setelah berhasil login akun Google via Firebase.
   - API Key dapat dibuat secara gratis melalui [Google AI Studio](https://aistudio.google.com/).
2. **Penyimpanan Terisolasi Multi-User (Android Keystore):**
   - Kunci disimpan di memori terenkripsi perangkat menggunakan `flutter_secure_storage`.
   - Menggunakan skema nama kunci terisolasi per akun: `gemini_api_key_<user_uid>`.
   - Jika pengguna berganti akun Google pada perangkat yang sama, akun lain tidak dapat membaca kunci tersebut.
3. **Validasi Mutlak di Layer Akses:**
   - Modul [`AiGuardService`](file:///d:/Project/Fastwork/screenrecording/lib/core/services/ai_guard_service.dart) dan [`VideoAiService`](file:///d:/Project/Fastwork/screenrecording/lib/core/services/video_ai_service.dart) menolak pemrosesan secara sistem jika user belum login atau belum memiliki key valid.

---

### 8.5 Konfigurasi Gradle Firebase Crashlytics & Google Analytics

Untuk mendukung pelaporan crash native dan symbol mapping di Android:

1. **Root `android/build.gradle.kts`:**
   Mendaftarkan classpath plugin Crashlytics Gradle:
   ```kotlin
   buildscript {
       dependencies {
           classpath("com.google.gms:google-services:4.4.2")
           classpath("com.google.firebase:firebase-crashlytics-gradle:3.0.3")
       }
   }
   ```

2. **App `android/app/build.gradle.kts`:**
   Menerapkan plugin Crashlytics secara kondisional jika `google-services.json` tersedia:
   ```kotlin
   if (file("google-services.json").exists()) {
       apply(plugin = "com.google.gms.google-services")
       apply(plugin = "com.google.firebase.crashlytics")
   }
   ```

3. **Pengujian Crash Manual (Verifikasi Crashlytics):**
   Untuk menguji apakah Crashlytics berhasil menangkap unhandled exception di Firebase Console:
   ```dart
   import 'package:firebase_crashlytics/firebase_crashlytics.dart';

   // Memicu test crash sengaja:
   FirebaseCrashlytics.instance.crash();
   ```

---

## 9. Cara Menjalankan Aplikasi

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
4. Izinkan dialog sistem Android: *"Start recording or casting with REKAM?"* ➔ Pilih **"Start now"**.
