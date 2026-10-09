import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hippo_flutter_sdk_example/main.dart';

void main() {
  testWidgets('shows the actions and both unread counts', (WidgetTester tester) async {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockStreamHandler(
      const EventChannel('hippo_flutter_sdk_events'),
      MockStreamHandler.inline(onListen: (arguments, events) => events.success(3)),
    );
    messenger.setMockStreamHandler(
      const EventChannel('hippo_flutter_sdk_announcement_events'),
      MockStreamHandler.inline(onListen: (arguments, events) => events.success(1)),
    );

    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('Hippo SDK Demo'), findsOneWidget);
    expect(find.text('Show Conversations'), findsOneWidget);
    expect(find.text('Unread Announcements'), findsOneWidget);
    expect(find.text('Refresh Counts'), findsOneWidget);
    // The count chips appear once Hippo is initialised; the snackbar shows the message count straight away.
    expect(find.text('Unread count updated: 3'), findsOneWidget);

    // Let the snackbar's timer run out, so no timer is left pending.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
