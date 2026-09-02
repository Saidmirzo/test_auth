import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

class DeviceService {
  static const _boxName = 'app_data';
  static const _deviceIdKey = 'device_id';

  Future<Map<String, dynamic>> payload() async {
    final deviceId = await _stableDeviceId();
    final package = await PackageInfo.fromPlatform();
    final plugin = DeviceInfoPlugin();

    var name = 'Unknown device';
    var osVersion = '';
    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      name = '${info.brand} ${info.model}'.trim();
      osVersion = 'Android ${info.version.release}';
    } else if (Platform.isIOS) {
      final info = await plugin.iosInfo;
      name = info.name;
      osVersion = '${info.systemName} ${info.systemVersion}';
    }

    return {
      'device_id': deviceId,
      'name': name,
      'platform': Platform.operatingSystem,
      'os_version': osVersion,
      'app_version': '${package.version}+${package.buildNumber}',
    };
  }

  Future<String> _stableDeviceId() async {
    final box = Hive.box(_boxName);
    final existing = box.get(_deviceIdKey) as String?;
    if (existing != null && existing.isNotEmpty) return existing;
    final created = const Uuid().v4();
    await box.put(_deviceIdKey, created);
    return created;
  }
}
