import 'hippo_flutter_sdk_platform_interface.dart';

/// The main class for interacting with the Hippo Flutter SDK.
///
/// This class provides methods for initializing the SDK, showing conversations,
/// managing user data, unread counts and push notifications.
///
/// In debug builds the plugin logs what it does — on the Dart side and on Android and iOS — with the tag
/// `HippoFlutterSdk`; `"debug"` in the [initHippo] config turns that on or off.
class HippoFlutterSdk {
  /// Initializes the Hippo SDK.
  ///
  /// This method must be called before any other Hippo methods.
  /// The [data] parameter is a JSON string containing the configuration details:
  /// `appKey`, `appType`, `environment`, `provider` (Android file provider), `deviceToken` (the FCM token, Android),
  /// optionally `apnsToken` (the APNs token as hex, iOS — the plugin also picks it up from the app delegate), `debug`
  /// (logging; defaults to debug builds), and `userData` (`userUniqueKey`, `fullName`, `email`, `phoneNumber`,
  /// `selectedlanguage`, `userIdentificationSecret`).
  Future<void> initHippo(String data) {
    return HippoFlutterSdkPlatform.instance.initHippo(data);
  }

  /// Presents the chat conversations view to the user.
  Future<void> showConversations() {
    return HippoFlutterSdkPlatform.instance.showConversations();
  }

  /// Clears all data related to the current user.
  ///
  /// This is useful when a user logs out of your application. The unread counts go back to 0.
  Future<void> clearHippoData() {
    return HippoFlutterSdkPlatform.instance.clearHippoData();
  }

  /// Asks Hippo for the number of unread messages and returns it.
  ///
  /// The count is also sent on [getUnreadCountStream]. Before [initHippo] it's the last count known (0 at first).
  Future<int?> getUnreadCount() {
    return HippoFlutterSdkPlatform.instance.getUnreadCount();
  }

  /// A stream that emits the unread message count whenever it changes.
  ///
  /// A new listener first gets the last count known. Announcements are counted separately, on
  /// [getUnreadAnnouncementCountStream].
  Stream<int> getUnreadCountStream() {
    return HippoFlutterSdkPlatform.instance.getUnreadCountStream();
  }

  /// Asks Hippo for the number of unread announcements and returns it.
  ///
  /// The count is also sent on [getUnreadAnnouncementCountStream].
  Future<int?> getUnreadAnnouncementCount() {
    return HippoFlutterSdkPlatform.instance.getUnreadAnnouncementCount();
  }

  /// A stream that emits the unread announcement count whenever it changes.
  Stream<int> getUnreadAnnouncementCountStream() {
    return HippoFlutterSdkPlatform.instance.getUnreadAnnouncementCountStream();
  }

  /// Opens a peer-to-peer chat.
  ///
  /// The [peerChatData] parameter is a JSON string containing the details
  /// for the peer chat, such as the transaction ID and user keys.
  Future<void> openPeerChat(String peerChatData) {
    return HippoFlutterSdkPlatform.instance.openPeerChat(peerChatData);
  }

  /// Whether a push message's data (FCM `RemoteMessage.data`) came from Hippo.
  Future<bool> isHippoNotification(Map<String, dynamic> data) {
    return HippoFlutterSdkPlatform.instance.isHippoNotification(data);
  }

  /// Hands a Hippo push message (FCM `RemoteMessage.data`) to the Hippo SDK.
  ///
  /// On Android, call it from both `FirebaseMessaging.onMessage` and the background message handler: Hippo shows its
  /// notification (tapping it opens the chat) and updates the unread counts. On iOS, Hippo's notifications arrive
  /// through APNs and the plugin handles them itself; calling this there updates the unread counts.
  ///
  /// Returns `false`, doing nothing, when the message isn't Hippo's.
  Future<bool> handleHippoNotification(Map<String, dynamic> data) {
    return HippoFlutterSdkPlatform.instance.handleHippoNotification(data);
  }
}
