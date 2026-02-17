import 'dart:io';

enum UploadStatus { uploading, success, error }

class UploadItem {
  final String id;
  final File? localFile; // Null if existing image
  String? serverUrl;     // Null until uploaded
  UploadStatus status;
  double progress;       // 0.0 to 1.0

  UploadItem({
    required this.id,
    this.localFile,
    this.serverUrl,
    this.status = UploadStatus.uploading,
    this.progress = 0.0,
  });
}
