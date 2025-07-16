import 'package:flutter_test/flutter_test.dart';
import 'package:hippo_flutter_sdk/hippo_flutter_sdk.dart';
import 'package:hippo_flutter_sdk/hippo_flutter_sdk_platform_interface.dart';
import 'package:hippo_flutter_sdk/hippo_flutter_sdk_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockHippoFlutterSdkPlatform
    with MockPlatformInterfaceMixin
    implements HippoFlutterSdkPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final HippoFlutterSdkPlatform initialPlatform = HippoFlutterSdkPlatform.instance;

  test('$MethodChannelHippoFlutterSdk is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelHippoFlutterSdk>());
  });

  test('getPlatformVersion', () async {
    HippoFlutterSdk hippoFlutterSdkPlugin = HippoFlutterSdk();
    MockHippoFlutterSdkPlatform fakePlatform = MockHippoFlutterSdkPlatform();
    HippoFlutterSdkPlatform.instance = fakePlatform;

    expect(await hippoFlutterSdkPlugin.getPlatformVersion(), '42');
  });
}
