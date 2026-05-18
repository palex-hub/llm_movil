import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static const String modelPath1_5B =
      '/storage/emulated/0/neuralqwen-2.5-1.5b-spanish.Q4_K_M.gguf';
  static const String modelPath3B =
      '/storage/emulated/0/qwen2.5-3b-instruct-q4_k_m.gguf';

  static Future<bool> requestStoragePermission() async {
    if (await Permission.manageExternalStorage.isGranted) return true;
    final status = await Permission.manageExternalStorage.request();
    return status.isGranted;
  }
}
