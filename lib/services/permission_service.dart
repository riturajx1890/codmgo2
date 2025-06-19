import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class PermissionService {
  static Future<void> requestInitialPermissions() async {
    List<Permission> permissionsToRequest = [
      Permission.location,
      Permission.notification,
    ];

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      permissionsToRequest.add(Permission.photos);
      permissionsToRequest.add(Permission.mediaLibrary);
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        // Android 13 (API 33) and above
        permissionsToRequest.add(Permission.photos); // Covers READ_MEDIA_IMAGES and READ_MEDIA_VIDEO
        permissionsToRequest.add(Permission.audio);   // Covers READ_MEDIA_AUDIO
      } else {
        // Android below 13 (API < 33)
        permissionsToRequest.add(Permission.storage);
      }
    }

    await permissionsToRequest.request();
  }
}