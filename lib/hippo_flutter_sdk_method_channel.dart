import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'hippo_flutter_sdk_platform_interface.dart';

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

  /// The event channel used to receive events from the native platform.
  ///
  /// This channel is used to receive broadcast streams of events from the native
  /// platform, such as updates to the unread count.
  @visibleForTesting
  final eventChannel = const EventChannel('hippo_flutter_sdk_events');

  /// Initializes the Hippo Flutter SDK with the given data.
  ///
  /// This method invokes the `initHippo` method on the native platform, passing
  /// the provided data as an argument.
  ///
  /// Returns a [Future] that completes when the initialization is complete.
  @override
  Future<void> initHippo(String data) {
    return methodChannel.invokeMethod<void>('initHippo', data);
  }

  /// Shows the conversations screen.
  ///
  /// This method invokes the `showConversations` method on the native platform.
  ///
  /// Returns a [Future] that completes when the conversations screen is shown.
  @override
  Future<void> showConversations() {
    return methodChannel.invokeMethod<void>('showConversations');
  }

  /// Clears the Hippo data.
  ///
  /// This method invokes the `clearHippoData` method on the native platform.
  ///
  /// Returns a [Future] that completes when the data is cleared.
  @override
  Future<void> clearHippoData() {
    return methodChannel.invokeMethod<void>('clearHippoData');
  }

  /// Gets the unread count.
  ///
  /// This method invokes the `getUnreadCount` method on the native platform and
  /// returns the result as an [int].
  ///
  /// Returns a [Future] that completes with the unread count, or `null` if the
  /// count is not available.
  @override
  Future<int?> getUnreadCount() {
    return methodChannel.invokeMethod<int>('getUnreadCount');
  }

  /// Opens a peer chat with the given peer chat data.
  ///
  /// This method invokes the `openPeerChat` method on the native platform, passing
  /// the provided peer chat data as an argument.
  ///
  /// Returns a [Future] that completes when the peer chat is opened.
  @override
  Future<void> openPeerChat(String peerChatData) {
    return methodChannel.invokeMethod<void>('openPeerChat', peerChatData);
  }

  /// Gets a stream of unread count updates.
  ///
  /// This method returns a [Stream] of [int] values representing the unread count,
  /// which is updated in real-time by the native platform.
  @override
  Stream<int> getUnreadCountStream() {
    return eventChannel.receiveBroadcastStream().map((event) => event as int);
  }
}
