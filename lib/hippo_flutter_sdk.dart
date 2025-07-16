import 'hippo_flutter_sdk_platform_interface.dart';

/// The main class for interacting with the Hippo Flutter SDK.
///
/// This class provides methods for initializing the SDK, showing conversations,
/// managing user data, and more.
class HippoFlutterSdk {
  /// Initializes the Hippo SDK.
  ///
  /// This method must be called before any other Hippo methods.
  /// The [data] parameter is a JSON string containing the configuration details.
  Future<void> initHippo(String data) {
    return HippoFlutterSdkPlatform.instance.initHippo(data);
  }

  /// Presents the chat conversations view to the user.
  Future<void> showConversations() {
    return HippoFlutterSdkPlatform.instance.showConversations();
  }

  /// Clears all data related to the current user.
  ///
  /// This is useful when a user logs out of your application.
  Future<void> clearHippoData() {
    return HippoFlutterSdkPlatform.instance.clearHippoData();
  }

  /// Gets the current number of unread messages for the user.
  Future<int?> getUnreadCount() {
    return HippoFlutterSdkPlatform.instance.getUnreadCount();
  }

  /// A stream that emits the unread message count whenever it changes.
  Stream<int> getUnreadCountStream() {
    return HippoFlutterSdkPlatform.instance.getUnreadCountStream();
  }

  /// Opens a peer-to-peer chat.
  ///
  /// The [peerChatData] parameter is a JSON string containing the details
  /// for the peer chat, such as the transaction ID and user keys.
  Future<void> openPeerChat(String peerChatData) {
    return HippoFlutterSdkPlatform.instance.openPeerChat(peerChatData);
  }
}
