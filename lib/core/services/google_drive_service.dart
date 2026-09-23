import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'auth_service.dart';

/// Hasil dari proses upload ke Google Drive
class DriveUploadResult {
  final bool isSuccess;
  final String? fileId;
  final String? webViewLink;
  final String? errorMessage;

  DriveUploadResult({
    required this.isSuccess,
    this.fileId,
    this.webViewLink,
    this.errorMessage,
  });
}

/// Service untuk mengunggah video hasil rekaman ke Google Drive pribadi pengguna
/// Menggunakan konsep No API Owner / No Default Service Account
class GoogleDriveService {
  static const String _appFolderName = 'REKAM Screen Recordings';

  /// Mendapatkan atau membuat folder khusus REKAM di Google Drive pengguna
  static Future<String?> _getOrCreateAppFolder(drive.DriveApi driveApi) async {
    try {
      final fileList = await driveApi.files.list(
        q: "mimeType = 'application/vnd.google-apps.folder' and name = '$_appFolderName' and trashed = false",
        $fields: 'files(id, name)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first.id;
      }

      // Jika belum ada, buat folder baru
      final folderMetadata = drive.File()
        ..name = _appFolderName
        ..mimeType = 'application/vnd.google-apps.folder';

      final createdFolder = await driveApi.files.create(folderMetadata);
      return createdFolder.id;
    } catch (e) {
      debugPrint('Error getOrCreateAppFolder: $e');
      return null;
    }
  }

  /// Mengunggah file video rekaman ke Google Drive pribadi user
  static Future<DriveUploadResult> uploadRecording({
    required File videoFile,
    required String fileName,
  }) async {
    try {
      if (!await videoFile.exists()) {
        return DriveUploadResult(
          isSuccess: false,
          errorMessage: 'File video tidak ditemukan di penyimpanan lokal.',
        );
      }

      final client = await AuthService.instance.getAuthenticatedClient();
      if (client == null) {
        return DriveUploadResult(
          isSuccess: false,
          errorMessage:
              'Sesi Google tidak aktif. Harap login dengan Google terlebih dahulu.',
        );
      }

      final driveApi = drive.DriveApi(client);
      final folderId = await _getOrCreateAppFolder(driveApi);

      final mediaStream = videoFile.openRead();
      final totalByteLength = await videoFile.length();
      final media = drive.Media(mediaStream, totalByteLength);

      final driveFile = drive.File()
        ..name = fileName
        ..mimeType = 'video/mp4';

      if (folderId != null) {
        driveFile.parents = [folderId];
      }

      final uploadedFile = await driveApi.files.create(
        driveFile,
        uploadMedia: media,
        $fields: 'id, name, webViewLink',
      );

      client.close();

      return DriveUploadResult(
        isSuccess: true,
        fileId: uploadedFile.id,
        webViewLink: uploadedFile.webViewLink,
      );
    } catch (e) {
      debugPrint('Error uploadRecording to Google Drive: $e');
      return DriveUploadResult(
        isSuccess: false,
        errorMessage: 'Gagal mengunggah video ke Google Drive: $e',
      );
    }
  }
}
