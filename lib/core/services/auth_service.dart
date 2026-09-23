import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

/// Client HTTP pembungkus otentikasi Google untuk request ke Google APIs (seperti Drive)
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
}

/// Service untuk menangani Firebase Authentication dengan Google Sign-In
/// serta mengelola sesi akun Google untuk akses personal Google Drive.
/// Memiliki graceful fallback jika Firebase belum terhubung (belum ada google-services.json).
class AuthService {
  static final AuthService instance = AuthService._internal();

  AuthService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      'email',
      'https://www.googleapis.com/auth/drive.file',
    ],
  );

  /// Helper untuk mengambil instance FirebaseAuth secara aman tanpa melempar exception saat offline
  FirebaseAuth? get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (e) {
      debugPrint('Firebase Auth not available (running in offline mode): $e');
      return null;
    }
  }

  /// Cek apakah Firebase sudah terinisialisasi dan tersedia
  bool get isFirebaseAvailable => _auth != null;

  /// Stream status autentikasi Firebase
  Stream<User?> get authStateChanges {
    final auth = _auth;
    if (auth == null) {
      return const Stream<User?>.empty();
    }
    return auth.authStateChanges();
  }

  /// User saat ini yang sedang login (null jika belum login atau Firebase belum aktif)
  User? get currentUser {
    final auth = _auth;
    if (auth == null) {
      return null;
    }
    try {
      return auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Melakukan Sign In menggunakan Google Account dan menghubungkannya ke Firebase Auth
  Future<User?> signInWithGoogle() async {
    final auth = _auth;
    if (auth == null) {
      throw Exception(
        'Firebase belum dikonfigurasi. Harap tambahkan file "google-services.json" ke direktori "android/app/" sesuai panduan di README.md untuk mengaktifkan Google Sign-In.',
      );
    }

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // Pengguna membatalkan dialog login
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await auth.signInWithCredential(credential);

      return userCredential.user;
    } catch (e) {
      debugPrint('Error signInWithGoogle: $e');
      rethrow;
    }
  }

  /// Mendapatkan authenticated HTTP client untuk Google APIs (seperti Drive)
  Future<GoogleAuthClient?> getAuthenticatedClient() async {
    try {
      GoogleSignInAccount? googleUser = _googleSignIn.currentUser;
      googleUser ??= await _googleSignIn.signInSilently();

      if (googleUser == null) {
        return null;
      }

      final authHeaders = await googleUser.authHeaders;
      return GoogleAuthClient(authHeaders);
    } catch (e) {
      debugPrint('Error getAuthenticatedClient: $e');
      return null;
    }
  }

  /// Logout dari Firebase dan Google Sign In
  Future<void> signOut() async {
    try {
      final auth = _auth;
      if (auth != null) {
        await auth.signOut();
      }
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Error signOut: $e');
      rethrow;
    }
  }
}
