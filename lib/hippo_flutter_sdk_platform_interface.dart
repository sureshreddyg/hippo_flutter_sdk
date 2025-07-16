import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'hippo_flutter_sdk_method_channel.dart';

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

  Future<void> initHippo(String data) {
    throw UnimplementedError('initHippo() has not been implemented.');
  }

  Future<void> showConversations() {
    throw UnimplementedError('showConversations() has not been implemented.');
  }

  Future<void> clearHippoData() {
    throw UnimplementedError('clearHippoData() has not been implemented.');
  }

  Future<int?> getUnreadCount() {
    throw UnimplementedError('getUnreadCount() has not been implemented.');
  }

  Future<void> openPeerChat(String peerChatData) {
    throw UnimplementedError('openPeerChat() has not been implemented.');
  }

  Stream<int> getUnreadCountStream() {
    throw UnimplementedError('getUnreadCountStream() has not been implemented.');
  }
}
