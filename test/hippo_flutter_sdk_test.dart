import 'package:flutter_test/flutter_test.dart';
import 'package:hippo_flutter_sdk/hippo_flutter_sdk_platform_interface.dart';
import 'package:hippo_flutter_sdk/hippo_flutter_sdk_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockHippoFlutterSdkPlatform
    with MockPlatformInterfaceMixin
    implements HippoFlutterSdkPlatform {
  @override
  Future<void> initHippo(String config) {
    return Future.value();
  }

  @override
  Future<void> showConversations() {
    return Future.value();
  }

  @override
  Future<void> openPeerChat(String peerChatData) {
    return Future.value();
  }

  @override
  Future<void> clearHippoData() {
    return Future.value();
  }

  @override
  Future<int> getUnreadCount() {
    return Future.value(0);
  }

  @override
  Stream<int> getUnreadCountStream() {
    return Stream.value(0);
  }
}

void main() {
  final HippoFlutterSdkPlatform initialPlatform =
      HippoFlutterSdkPlatform.instance;

  test('$MethodChannelHippoFlutterSdk is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelHippoFlutterSdk>());
  });
}
