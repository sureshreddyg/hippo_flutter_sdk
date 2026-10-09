import 'package:flutter_test/flutter_test.dart';
import 'package:hippo_flutter_sdk/hippo_flutter_sdk.dart';
import 'package:hippo_flutter_sdk/hippo_flutter_sdk_platform_interface.dart';
import 'package:hippo_flutter_sdk/hippo_flutter_sdk_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockHippoFlutterSdkPlatform
    with MockPlatformInterfaceMixin
    implements HippoFlutterSdkPlatform {
  final List<String> calls = [];

  @override
  Future<void> initHippo(String config) async => calls.add('initHippo');

  @override
  Future<void> showConversations() async => calls.add('showConversations');

  @override
  Future<void> openPeerChat(String peerChatData) async => calls.add('openPeerChat');

  @override
  Future<void> clearHippoData() async => calls.add('clearHippoData');

  @override
  Future<int> getUnreadCount() async => 3;

  @override
  Stream<int> getUnreadCountStream() => Stream.fromIterable([3, 0]);

  @override
  Future<int> getUnreadAnnouncementCount() async => 2;

  @override
  Stream<int> getUnreadAnnouncementCountStream() => Stream.value(2);

  @override
  Future<bool> isHippoNotification(Map<String, dynamic> data) async => data['push_source'] == 'FUGU';

  @override
  Future<bool> handleHippoNotification(Map<String, dynamic> data) async => data['push_source'] == 'FUGU';
}

void main() {
  final HippoFlutterSdkPlatform initialPlatform = HippoFlutterSdkPlatform.instance;

  test('$MethodChannelHippoFlutterSdk is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelHippoFlutterSdk>());
  });

  group('HippoFlutterSdk passes every call to the platform', () {
    late MockHippoFlutterSdkPlatform platform;
    final hippo = HippoFlutterSdk();

    setUp(() {
      platform = MockHippoFlutterSdkPlatform();
      HippoFlutterSdkPlatform.instance = platform;
    });

    test('screens and sign-out', () async {
      await hippo.initHippo('{}');
      await hippo.showConversations();
      await hippo.openPeerChat('{}');
      await hippo.clearHippoData();
      expect(platform.calls, ['initHippo', 'showConversations', 'openPeerChat', 'clearHippoData']);
    });

    test('message and announcement counts are separate', () async {
      expect(await hippo.getUnreadCount(), 3);
      expect(await hippo.getUnreadAnnouncementCount(), 2);
      expect(await hippo.getUnreadCountStream().toList(), [3, 0]);
      expect(await hippo.getUnreadAnnouncementCountStream().toList(), [2]);
    });

    test('notifications', () async {
      expect(await hippo.isHippoNotification({'push_source': 'FUGU'}), isTrue);
      expect(await hippo.handleHippoNotification({'push_source': 'FUGU'}), isTrue);
      expect(await hippo.handleHippoNotification({'title': 'An order update'}), isFalse);
    });
  });
}
