import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'hippo_flutter_sdk_platform_interface.dart';

/// An implementation of [HippoFlutterSdkPlatform] that uses method channels.
class MethodChannelHippoFlutterSdk extends HippoFlutterSdkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('hippo_flutter_sdk');

  @visibleForTesting
  final eventChannel = const EventChannel('hippo_flutter_sdk_events');

  @override
  Future<void> initHippo(String data) =>
      methodChannel.invokeMethod<void>('initHippo', data);

  @override
  Future<void> showConversations() =>
      methodChannel.invokeMethod<void>('showConversations');

  @override
  Future<void> clearHippoData() =>
      methodChannel.invokeMethod<void>('clearHippoData');

  @override
  Future<int?> getUnreadCount() async {
    return await methodChannel.invokeMethod<int>('getUnreadCount');
  }

  @override
  Future<void> openPeerChat(String peerChatData) async {
    await methodChannel.invokeMethod<void>('openPeerChat', peerChatData);
  }

  @override
  Stream<int> getUnreadCountStream() {
    return eventChannel.receiveBroadcastStream().map((event) => event as int);
  }
}
