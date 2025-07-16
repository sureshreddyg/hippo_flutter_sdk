
import 'hippo_flutter_sdk_platform_interface.dart';

class HippoFlutterSdk {
  Future<void> initHippo(String data) {
    return HippoFlutterSdkPlatform.instance.initHippo(data);
  }

  Future<void> showConversations() {
    return HippoFlutterSdkPlatform.instance.showConversations();
  }

  Future<void> clearHippoData() {
    return HippoFlutterSdkPlatform.instance.clearHippoData();
  }

  Future<int?> getUnreadCount() {
    return HippoFlutterSdkPlatform.instance.getUnreadCount();
  }

  Stream<int> getUnreadCountStream() {
    return HippoFlutterSdkPlatform.instance.getUnreadCountStream();
  }

  Future<void> openPeerChat(String peerChatData) {
    return HippoFlutterSdkPlatform.instance.openPeerChat(peerChatData);
  }
}
