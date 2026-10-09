import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hippo_flutter_sdk/hippo_flutter_sdk_method_channel.dart';
import 'package:hippo_flutter_sdk/src/hippo_log.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('hippo_flutter_sdk');
  final platform = MethodChannelHippoFlutterSdk();
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    HippoLog.enabled = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'getUnreadCount':
          return 4;
        case 'getUnreadAnnouncementCount':
          return 1;
        case 'isHippoNotification':
        case 'handleHippoNotification':
          return (call.arguments as Map)['push_source'] == 'FUGU';
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  group('initHippo', () {
    test('sends the config with "debug" set to the build, so the native logs follow it', () async {
      await platform.initHippo(jsonEncode({'appKey': 'abcd1234', 'userData': {'userUniqueKey': 'u-1'}}));
      final sent = jsonDecode(calls.single.arguments as String) as Map<String, dynamic>;
      expect(calls.single.method, 'initHippo');
      expect(sent['debug'], isTrue);
      expect(sent['appKey'], 'abcd1234');
      expect(sent['userData'], {'userUniqueKey': 'u-1'});
    });

    test("keeps the app's own debug flag, and logging follows it", () async {
      await platform.initHippo(jsonEncode({'appKey': 'abcd1234', 'debug': false}));
      expect(jsonDecode(calls.single.arguments as String)['debug'], isFalse);
      expect(HippoLog.enabled, isFalse);
    });

    test('data that is not a JSON object goes as it is', () {
      expect(MethodChannelHippoFlutterSdk.withDebugFlag('not json'), 'not json');
      expect(MethodChannelHippoFlutterSdk.withDebugFlag('[1, 2]'), '[1, 2]');
    });
  });

  test('counts come back as ints', () async {
    expect(await platform.getUnreadCount(), 4);
    expect(await platform.getUnreadAnnouncementCount(), 1);
    expect(calls.map((c) => c.method), ['getUnreadCount', 'getUnreadAnnouncementCount']);
  });

  group('notifications', () {
    test("a Hippo push's data is sent as strings", () async {
      final data = {'push_source': 'FUGU', 'channel_id': 42, 'is_announcement_push': 0, 'aps': {'badge': 1}};
      expect(await platform.handleHippoNotification(data), isTrue);
      expect(calls.single.arguments, {
        'push_source': 'FUGU',
        'channel_id': '42',
        'is_announcement_push': '0',
        'aps': '{"badge":1}',
      });
    });

    test('another push is not Hippo\'s', () async {
      expect(await platform.isHippoNotification({'title': 'Your order is on its way'}), isFalse);
      expect(await platform.handleHippoNotification({'title': 'Your order is on its way'}), isFalse);
    });

    test('a missing value is an empty string', () {
      expect(MethodChannelHippoFlutterSdk.stringMap({'a': null, 'b': 'x'}), {'a': '', 'b': 'x'});
    });
  });

  group('HippoLog', () {
    test('masks keys and tokens', () {
      expect(HippoLog.mask('f3a4213c67b4feb32bef5bc1db86434e'), 'f3a4…(32)');
      expect(HippoLog.mask('abc'), '…(3)');
      expect(HippoLog.mask(null), '(none)');
    });

    test('the config log never shows a secret', () {
      final shown = HippoLog.describeConfig({
        'appKey': 'f3a4213c67b4feb32bef5bc1db86434e',
        'deviceToken': 'fcm-token-1234567890',
        'userData': {'userUniqueKey': 'u-1', 'email': 'pat@example.com', 'userIdentificationSecret': 'top-secret'},
      });
      expect(shown, isNot(contains('213c67b4')));
      expect(shown, isNot(contains('fcm-token-1234567890')));
      expect(shown, isNot(contains('pat@example.com')));
      expect(shown, isNot(contains('top-secret')));
      expect(shown, contains('u-1'));
    });
  });
}
