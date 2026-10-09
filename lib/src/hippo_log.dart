import 'dart:convert';

import 'package:flutter/foundation.dart';

/// The plugin's debug log on the Dart side: every call the app makes to Hippo, what comes back, and every unread
/// count the native SDKs report.
///
/// On in debug builds, off in release. `"debug": true` or `false` in the `initHippo` config overrides it, and the
/// Android and iOS sides follow the same flag. Keys, secrets and tokens are masked.
class HippoLog {
  HippoLog._();

  /// Whether the plugin logs. Defaults to [kDebugMode].
  static bool enabled = kDebugMode;

  /// Logs [message] with the plugin's tag when logging is on.
  static void d(String message) {
    if (enabled) {
      debugPrint('[HippoFlutterSdk] $message');
    }
  }

  /// A key, secret or token as a log shows it: its first four characters and its length ("f3a4…(32)").
  static String mask(Object? value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty) {
      return '(none)';
    }
    return text.length <= 4 ? '…(${text.length})' : '${text.substring(0, 4)}…(${text.length})';
  }

  /// The init config as a log shows it: what was set, with every secret masked.
  static String describeConfig(Map<String, dynamic> config) {
    final user = config['userData'];
    final shown = <String, Object?>{
      'appKey': mask(config['appKey']),
      'appType': config['appType'],
      'environment': config['environment'],
      'deviceToken': mask(config['deviceToken']),
      if (config.containsKey('apnsToken')) 'apnsToken': mask(config['apnsToken']),
      if (config.containsKey('userIdentificationSecret'))
        'userIdentificationSecret': mask(config['userIdentificationSecret']),
      'debug': config['debug'],
      if (user is Map)
        'userData': {
          'userUniqueKey': user['userUniqueKey'],
          'fullName': user['fullName'],
          'email': user['email'] == null ? null : mask(user['email']),
          'phoneNumber': user['phoneNumber'] == null ? null : mask(user['phoneNumber']),
          if (user.containsKey('userIdentificationSecret'))
            'userIdentificationSecret': mask(user['userIdentificationSecret']),
        },
    };
    return jsonEncode(shown);
  }
}
