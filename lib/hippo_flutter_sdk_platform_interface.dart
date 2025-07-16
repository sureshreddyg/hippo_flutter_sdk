import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'hippo_flutter_sdk_method_channel.dart';

/// The interface that platform-specific implementations of `hippo_flutter_sdk` must extend.
///
/// This class defines the API for the hippo_flutter_sdk plugin.
/// Platform-specific implementations of this class should be set as the default
/// instance of [HippoFlutterSdkPlatform] when they register themselves.
abstract class HippoFlutterSdkPlatform extends PlatformInterface {
  /// Constructs a HippoFlutterSdkPlatform.
  HippoFlutterSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static HippoFlutterSdkPlatform _instance = MethodChannelHippoFlutterSdk();

  /// The default instance of [HippoFlutterSdkPlatform] to use.
  ///
  /// Defaults to [MethodChannelHippoFlutterSdk].
  static HippoFlutterSdkPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [HippoFlutterSdkPlatform] when
  /// they register themselves.
  static set instance(HippoFlutterSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Initializes the Hippo SDK on the native platform.
  Future<void> initHippo(String data) {
    throw UnimplementedError('initHippo() has not been implemented.');
  }

  /// Presents the native view for chat conversations.
  Future<void> showConversations() {
    throw UnimplementedError('showConversations() has not been implemented.');
  }

  /// Clears all user data from the native platform.
  Future<void> clearHippoData() {
    throw UnimplementedError('clearHippoData() has not been implemented.');
  }

  /// Retrieves the unread message count from the native platform.
  Future<int?> getUnreadCount() {
    throw UnimplementedError('getUnreadCount() has not been implemented.');
  }

  /// Opens a peer-to-peer chat on the native platform.
  Future<void> openPeerChat(String peerChatData) {
    throw UnimplementedError('openPeerChat() has not been implemented.');
  }

  /// A stream of unread message counts from the native platform.
  Stream<int> getUnreadCountStream() {
    throw UnimplementedError(
      'getUnreadCountStream() has not been implemented.',
    );
  }
}
