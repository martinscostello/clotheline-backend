import 'dart:io';
import 'package:image_picker/image_picker.dart'; // [NEW] Added for XFile

enum UploadStatus { uploading, success, error }

class UploadItem {
  final String id;
  final File? localFile; // Support Mobile offline caching
  final XFile? xFile;    // Support Web DOM byte parsing
  String? serverUrl;
  UploadStatus status;
  double progress;

  UploadItem({
    required this.id,
    this.localFile,
    this.xFile,
    this.serverUrl,
    this.status = UploadStatus.uploading,
    this.progress = 0.0,
  });
}
