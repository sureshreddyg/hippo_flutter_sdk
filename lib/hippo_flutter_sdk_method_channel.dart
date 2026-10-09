import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'hippo_flutter_sdk_platform_interface.dart';
import 'src/hippo_log.dart';

/// An implementation of [HippoFlutterSdkPlatform] that uses method channels.
///
/// This class provides a platform-specific implementation of the Hippo Flutter SDK
/// using method channels to interact with the native platform.
class MethodChannelHippoFlutterSdk extends HippoFlutterSdkPlatform {
  /// The method channel used to interact with the native platform.
  ///
  /// This channel is used to invoke methods on the native platform and receive
  /// results asynchronously.
  @visibleForTesting
  final methodChannel = const MethodChannel('hippo_flutter_sdk');

  /// The event channel the native platform sends the unread message count on, whenever it changes.
  @visibleForTesting
  final eventChannel = const EventChannel('hippo_flutter_sdk_events');

  /// The event channel the native platform sends the unread announcement count on, whenever it changes.
  @visibleForTesting
  final announcementEventChannel = const EventChannel('hippo_flutter_sdk_announcement_events');

  // One native subscription per count, shared by every listener: an event channel takes one listener at a time, so a
  // second receiveBroadcastStream() would take the counts away from the first.
  Stream<int>? _unreadCounts;
  Stream<int>? _announcementCounts;

  /// Initializes the Hippo Flutter SDK with the given data.
  ///
  /// This method invokes the `initHippo` method on the native platform, passing
  /// the provided data as an argument. Unless the data says otherwise, `"debug"` is
  /// set to whether this is a debug build, which turns the native logs on or off.
  ///
  /// Returns a [Future] that completes when the initialization is complete.
  @override
  Future<void> initHippo(String data) async {
    final config = withDebugFlag(data);
    HippoLog.d('initHippo → native');
    await methodChannel.invokeMethod<void>('initHippo', config);
    HippoLog.d('initHippo: done');
  }

  /// Shows the conversations screen.
  ///
  /// This method invokes the `showConversations` method on the native platform.
  ///
  /// Returns a [Future] that completes when the conversations screen is shown.
  @override
  Future<void> showConversations() async {
    HippoLog.d('showConversations: opening the chats screen');
    await methodChannel.invokeMethod<void>('showConversations');
  }

  /// Clears the Hippo data.
  ///
  /// This method invokes the `clearHippoData` method on the native platform.
  ///
  /// Returns a [Future] that completes when the data is cleared.
  @override
  Future<void> clearHippoData() async {
    HippoLog.d('clearHippoData: signing the user out of Hippo');
    await methodChannel.invokeMethod<void>('clearHippoData');
  }

  /// Asks Hippo for the unread message count.
  ///
  /// The native SDK fetches the count from Hippo; the answer is also sent on [getUnreadCountStream].
  ///
  /// Returns a [Future] that completes with the unread count, or `null` if the
  /// count is not available.
  @override
  Future<int?> getUnreadCount() async {
    HippoLog.d('getUnreadCount: asking Hippo');
    final count = await methodChannel.invokeMethod<int>('getUnreadCount');
    HippoLog.d('getUnreadCount: $count');
    return count;
  }

  /// Asks Hippo for the unread announcement count.
  ///
  /// The answer is also sent on [getUnreadAnnouncementCountStream].
  @override
  Future<int?> getUnreadAnnouncementCount() async {
    HippoLog.d('getUnreadAnnouncementCount: asking Hippo');
    final count = await methodChannel.invokeMethod<int>('getUnreadAnnouncementCount');
    HippoLog.d('getUnreadAnnouncementCount: $count');
    return count;
  }

  /// Opens a peer chat with the given peer chat data.
  ///
  /// This method invokes the `openPeerChat` method on the native platform, passing
  /// the provided peer chat data as an argument.
  ///
  /// Returns a [Future] that completes when the peer chat is opened.
  @override
  Future<void> openPeerChat(String peerChatData) async {
    HippoLog.d('openPeerChat: opening the chat screen for $peerChatData');
    await methodChannel.invokeMethod<void>('openPeerChat', peerChatData);
  }

  /// Gets a stream of unread message counts.
  ///
  /// This method returns a [Stream] of [int] values representing the unread message count,
  /// which is updated in real-time by the native platform. A new listener first gets the
  /// last count the native platform knows.
  @override
  Stream<int> getUnreadCountStream() {
    return _unreadCounts ??= eventChannel.receiveBroadcastStream().map(_count('unread messages'));
  }

  /// Gets a stream of unread announcement counts.
  @override
  Stream<int> getUnreadAnnouncementCountStream() {
    return _announcementCounts ??=
        announcementEventChannel.receiveBroadcastStream().map(_count('unread announcements'));
  }

  /// Whether a push message's data came from Hippo (`push_source` FUGU or HIPPO).
  @override
  Future<bool> isHippoNotification(Map<String, dynamic> data) async {
    final isHippo = await methodChannel.invokeMethod<bool>('isHippoNotification', stringMap(data)) ?? false;
    HippoLog.d('isHippoNotification: $isHippo (push_source ${data['push_source']})');
    return isHippo;
  }

  /// Hands a Hippo push message to the native SDK: on Android it shows Hippo's notification (which opens the chat
  /// when tapped) and updates the unread counts; on iOS it updates the unread counts.
  @override
  Future<bool> handleHippoNotification(Map<String, dynamic> data) async {
    HippoLog.d('handleHippoNotification: push_source ${data['push_source']}, keys ${data.keys.toList()}');
    final handled = await methodChannel.invokeMethod<bool>('handleHippoNotification', stringMap(data)) ?? false;
    HippoLog.d('handleHippoNotification: ${handled ? 'handed to Hippo' : 'not a Hippo message'}');
    return handled;
  }

  static int Function(dynamic) _count(String label) {
    return (dynamic event) {
      final count = (event as num).toInt();
      HippoLog.d('$label: $count');
      return count;
    };
  }

  /// [data] with `"debug"` set: the app's own value when it gives one, else whether this is a debug build. The
  /// native sides log while it's true. Data that isn't a JSON object goes as it is (the native side reports it).
  @visibleForTesting
  static String withDebugFlag(String data) {
    final Object? decoded;
    try {
      decoded = jsonDecode(data);
    } on FormatException {
      return data;
    }
    if (decoded is! Map<String, dynamic>) {
      return data;
    }
    final debug = decoded['debug'];
    if (debug is bool) {
      HippoLog.enabled = debug;
    } else {
      decoded['debug'] = HippoLog.enabled;
    }
    HippoLog.d('initHippo config: ${HippoLog.describeConfig(decoded)}');
    return jsonEncode(decoded);
  }

  /// A push message's data as the native SDKs take it: every value a string (FCM data values already are; anything
  /// else is written as JSON).
  @visibleForTesting
  static Map<String, String> stringMap(Map<String, dynamic> data) {
    return data.map((key, value) {
      if (value == null) {
        return MapEntry(key, '');
      }
      return MapEntry(key, value is String ? value : jsonEncode(value));
    });
  }
}
